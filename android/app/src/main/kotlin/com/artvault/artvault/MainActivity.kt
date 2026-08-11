package com.artvault.artvault

import android.os.Build
import androidx.biometric.BiometricManager
import androidx.biometric.BiometricPrompt
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.nio.ByteBuffer
import java.nio.ByteOrder
import org.tensorflow.lite.Interpreter

class MainActivity : FlutterFragmentActivity() {

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "artvault/biometrics",
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "authenticateClass" -> {
                    val klass = call.argument<String>("class") ?: "strong"
                    authenticateClass(klass, result)
                }
                "embed" -> {
                    val input = call.argument<List<Double>>("input")
                    if (input == null) {
                        result.error("bad_input", "embedding input is null", null)
                        return@setMethodCallHandler
                    }
                    try {
                        result.success(embed(input))
                    } catch (e: Exception) {
                        result.error("embed_failed", e.message, null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    // ---------------------------------------------------------- Face model --

    @Volatile
    private var faceModel: Interpreter? = null

    @Synchronized
    private fun getFaceModel(): Interpreter {
        faceModel?.let { return it }
        // Flutter bundles app assets under flutter_assets/ inside the APK.
        var bytes: ByteArray? = null
        for (path in listOf(
            "flutter_assets/assets/models/mobilefacenet.tflite",
            "assets/models/mobilefacenet.tflite",
        )) {
            try {
                bytes = assets.open(path).use { it.readBytes() }
                break
            } catch (e: Exception) {
                // try next candidate
            }
        }
        val data = bytes ?: throw IllegalStateException("mobilefacenet.tflite asset not found")
        // TFLite requires the model buffer to be DIRECT (native order); a heap
        // buffer from ByteBuffer.wrap() makes Interpreter throw, which was
        // silently swallowed and blocked enrollment entirely.
        val modelBuffer = ByteBuffer.allocateDirect(data.size).order(ByteOrder.nativeOrder())
        modelBuffer.put(data)
        modelBuffer.rewind()
        return Interpreter(modelBuffer).also { faceModel = it }
    }

    /**
     * Runs the MobileFaceNet embedding model on a 112x112x3 RGB input
     * normalized to [-1, 1] and returns the L2-normalized embedding vector.
     */
    private fun embed(input: List<Double>): List<Float> {
        val model = getFaceModel()
        val n = 112 * 112 * 3
        require(input.size == n) { "expected $n floats, got ${input.size}" }

        val inBuffer = ByteBuffer.allocateDirect(n * 4).order(ByteOrder.nativeOrder())
        val inFloats = inBuffer.asFloatBuffer()
        for (v in input) inFloats.put(v.toFloat())
        inFloats.rewind()

        val outShape = model.getOutputTensor(0).shape()
        val dim = if (outShape.isNotEmpty()) outShape[outShape.size - 1] else 192
        val outArray = Array(1) { FloatArray(dim) }
        model.run(inBuffer, outArray)

        var norm = 0.0
        for (v in outArray[0]) norm += v * v
        norm = Math.sqrt(norm)
        if (norm == 0.0) return outArray[0].toList()
        val inv = 1.0 / norm
        return outArray[0].map { (it * inv).toFloat() }
    }

    // ------------------------------------------------------------ Biometrics --

    /**
     * Shows a BiometricPrompt restricted to ONE biometric class so the app can
     * genuinely separate "fingerprint" (BIOMETRIC_STRONG, Class 3) from
     * "face unlock" (BIOMETRIC_WEAK, Class 2) instead of letting the system
     * pick whichever it prefers. Falls back to the unrestricted prompt on
     * Android < 11 where setAllowedAuthenticators is unavailable.
     */
    private fun authenticateClass(klass: String, result: MethodChannel.Result) {
        val executor = ContextCompat.getMainExecutor(this)
        val prompt = BiometricPrompt(
            this,
            executor,
            object : BiometricPrompt.AuthenticationCallback() {
                override fun onAuthenticationSucceeded(
                    authenticationResult: BiometricPrompt.AuthenticationResult,
                ) {
                    result.success(true)
                }

                override fun onAuthenticationError(errorCode: Int, errString: CharSequence) {
                    // Cancelled, lockout, or the requested class isn't enrolled.
                    result.success(false)
                }

                override fun onAuthenticationFailed() {
                    // Bad scan — keep the prompt open for another attempt.
                }
            },
        )

        val builder = BiometricPrompt.PromptInfo.Builder()
            .setTitle("Unlock ArtVault")
            .setSubtitle("Verify your identity")
            .setNegativeButtonText("Cancel")

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            val authenticators = if (klass == "weak") {
                BiometricManager.Authenticators.BIOMETRIC_WEAK
            } else {
                BiometricManager.Authenticators.BIOMETRIC_STRONG
            }
            builder.setAllowedAuthenticators(authenticators)
        }

        try {
            prompt.authenticate(builder.build())
        } catch (e: Exception) {
            result.success(false)
        }
    }
}
