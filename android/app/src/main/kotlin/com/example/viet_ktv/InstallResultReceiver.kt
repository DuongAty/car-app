package com.example.viet_ktv

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.pm.PackageInstaller
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.util.Log
import io.flutter.plugin.common.MethodChannel

/**
 * Holds the `viet_ktv/system` channel so a PackageInstaller session outcome
 * can be reported back to Dart.
 *
 * The status callback is delivered to a manifest-declared receiver, which the
 * system can start without an Activity, so the channel lives here rather than
 * on [MainActivity]. Reporting is best effort by design: on a successful
 * self-update the process is replaced and there is no engine left to talk to,
 * so an absent channel (or an absent Dart handler) is logged and dropped, never
 * treated as an error.
 */
object InstallStatusBridge {
    /** Explicit action the install-session PendingIntent is sent with. */
    const val ACTION = "com.example.viet_ktv.INSTALL_STATUS"

    /** Method invoked on the Dart side of `viet_ktv/system`. */
    const val METHOD = "onInstallStatus"

    const val OUTCOME_PENDING_USER_ACTION = "pendingUserAction"
    const val OUTCOME_SUCCESS = "success"
    const val OUTCOME_FAILED = "failed"

    /**
     * [PackageInstaller.STATUS_FAILURE_ABORTED] — the user pressed Back or
     * Cancel on the system confirmation dialog. This is not a rejection of
     * the package; the same checksum-verified file is still good and should
     * not be re-downloaded.
     */
    const val OUTCOME_CANCELLED = "cancelled"

    private const val TAG = "InstallStatus"

    private val mainHandler = Handler(Looper.getMainLooper())

    @Volatile
    private var channel: MethodChannel? = null

    fun attach(target: MethodChannel) {
        channel = target
    }

    /**
     * Identity-checked so a destroyed Activity cannot clear a channel that a
     * newly created one has already installed.
     */
    fun detach(target: MethodChannel) {
        if (channel === target) {
            channel = null
        }
    }

    fun report(outcome: String, status: Int, message: String?) {
        Log.i(TAG, "APK install $outcome (status=$status, message=$message)")
        val target = channel ?: return
        val payload = hashMapOf<String, Any?>(
            "outcome" to outcome,
            "status" to status,
            "message" to message,
        )
        mainHandler.post {
            try {
                target.invokeMethod(METHOD, payload)
            } catch (error: Throwable) {
                Log.w(TAG, "Could not deliver the install outcome to Dart.", error)
            }
        }
    }
}

/**
 * Receives PackageInstaller session status callbacks.
 *
 * For a non-privileged installer `PackageInstaller.Session.commit()` installs
 * nothing on its own. It fires the supplied IntentSender with
 * [PackageInstaller.EXTRA_STATUS] set to
 * [PackageInstaller.STATUS_PENDING_USER_ACTION] and the actual system
 * confirmation screen nested under [Intent.EXTRA_INTENT]. Pulling that nested
 * Intent out and starting it is what makes the installer appear; without it
 * the download simply goes nowhere.
 */
class InstallResultReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != InstallStatusBridge.ACTION) {
            return
        }
        val status = intent.getIntExtra(
            PackageInstaller.EXTRA_STATUS,
            PackageInstaller.STATUS_FAILURE,
        )
        val message = intent.getStringExtra(PackageInstaller.EXTRA_STATUS_MESSAGE)
        when (status) {
            PackageInstaller.STATUS_PENDING_USER_ACTION ->
                startConfirmation(context, intent, status, message)
            PackageInstaller.STATUS_SUCCESS ->
                InstallStatusBridge.report(
                    InstallStatusBridge.OUTCOME_SUCCESS,
                    status,
                    message,
                )
            // STATUS_FAILURE_ABORTED is what the system reports when the user
            // dismisses the confirmation dialog (Back/Cancel) — a cancellation,
            // not a rejection of the file itself. Reported separately so Dart
            // can keep the verified APK instead of discarding it.
            PackageInstaller.STATUS_FAILURE_ABORTED ->
                InstallStatusBridge.report(
                    InstallStatusBridge.OUTCOME_CANCELLED,
                    status,
                    message,
                )
            // STATUS_FAILURE and its BLOCKED/CONFLICT/INCOMPATIBLE/INVALID/
            // STORAGE variants. All of them mean this exact file will not
            // install, so Dart is told rather than left claiming success.
            else ->
                InstallStatusBridge.report(
                    InstallStatusBridge.OUTCOME_FAILED,
                    status,
                    message,
                )
        }
    }

    private fun startConfirmation(
        context: Context,
        intent: Intent,
        status: Int,
        message: String?,
    ) {
        val confirmation = confirmationIntent(intent)
        if (confirmation == null) {
            InstallStatusBridge.report(
                InstallStatusBridge.OUTCOME_FAILED,
                status,
                "The install confirmation intent was missing.",
            )
            return
        }
        // A receiver has no task of its own to start the dialog in.
        confirmation.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        try {
            context.startActivity(confirmation)
            InstallStatusBridge.report(
                InstallStatusBridge.OUTCOME_PENDING_USER_ACTION,
                status,
                message,
            )
        } catch (error: Throwable) {
            InstallStatusBridge.report(
                InstallStatusBridge.OUTCOME_FAILED,
                status,
                error.message ?: "Cannot open the system installer.",
            )
        }
    }

    @Suppress("DEPRECATION")
    private fun confirmationIntent(intent: Intent): Intent? {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            intent.getParcelableExtra(Intent.EXTRA_INTENT, Intent::class.java)
        } else {
            intent.getParcelableExtra(Intent.EXTRA_INTENT)
        }
    }
}
