package com.jadwalpintar

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.provider.Settings
import androidx.core.app.ActivityCompat
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    private var pendingPermissionResult: MethodChannel.Result? = null

    companion object {
        private const val REQUEST_STORAGE = 1001
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val messenger = flutterEngine.dartExecutor.binaryMessenger

        // ANDROID_ID asli (Settings.Secure) — device_info_plus tidak
        // menyediakannya (id di sana = Build.ID). Tanpa permission.
        MethodChannel(messenger, "jadwalpintar/device")
            .setMethodCallHandler { call, result ->
                if (call.method == "getAndroidId") {
                    try {
                        result.success(
                            Settings.Secure.getString(
                                contentResolver,
                                Settings.Secure.ANDROID_ID,
                            ),
                        )
                    } catch (e: Exception) {
                        result.success(null)
                    }
                } else {
                    result.notImplemented()
                }
            }

        // Update APK murni dalam aplikasi (tanpa downloader lain):
        // izin storage, folder Download, cek versi/tanda tangan,
        // install & uninstall. Tanpa permission tambahan selain storage.
        MethodChannel(messenger, "jadwalpintar/update")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "hasStoragePermission" ->
                        result.success(hasStoragePermission())

                    "requestStoragePermission" -> {
                        if (hasStoragePermission()) {
                            result.success(true)
                        } else if (Build.VERSION.SDK_INT < 23) {
                            result.success(true)
                        } else {
                            pendingPermissionResult = result
                            ActivityCompat.requestPermissions(
                                this,
                                arrayOf(
                                    Manifest.permission.WRITE_EXTERNAL_STORAGE,
                                ),
                                REQUEST_STORAGE,
                            )
                        }
                    }

                    "getPublicDownloadsDir" -> {
                        val dir =
                            Environment.getExternalStoragePublicDirectory(
                                Environment.DIRECTORY_DOWNLOADS,
                            )
                        result.success(dir?.absolutePath)
                    }

                    "getAppDownloadsDir" -> {
                        val dir = getExternalFilesDir(
                            Environment.DIRECTORY_DOWNLOADS,
                        )
                        result.success(dir?.absolutePath)
                    }

                    "getInstalledVersionCode" -> {
                        try {
                            val info = packageManager.getPackageInfo(
                                packageName,
                                signingFlags(),
                            )
                            result.success(versionCodeOf(info))
                        } catch (e: Exception) {
                            result.success(-1L)
                        }
                    }

                    "getArchiveVersionCode" -> {
                        val path = call.argument<String>("path")
                        if (path == null) {
                            result.success(-1L)
                        } else {
                            try {
                                val info =
                                    packageManager.getPackageArchiveInfo(
                                        path,
                                        signingFlags(),
                                    )
                                result.success(
                                    if (info == null) -1L
                                    else versionCodeOf(info),
                                )
                            } catch (e: Exception) {
                                result.success(-1L)
                            }
                        }
                    }

                    "signaturesMatch" -> {
                        val path = call.argument<String>("path")
                        if (path == null) {
                            result.success(false)
                        } else {
                            try {
                                val installed =
                                    packageManager.getPackageInfo(
                                        packageName,
                                        signingFlags(),
                                    )
                                val archive =
                                    packageManager.getPackageArchiveInfo(
                                        path,
                                        signingFlags(),
                                    )
                                val a = firstSignature(installed)
                                val b = firstSignature(archive)
                                result.success(
                                    a != null && b != null &&
                                        a.contentEquals(b),
                                )
                            } catch (e: Exception) {
                                result.success(false)
                            }
                        }
                    }

                    "installApk" -> {
                        val path = call.argument<String>("path")
                        try {
                            val uri = FileProvider.getUriForFile(
                                this,
                                "$packageName.fileprovider",
                                File(path!!),
                            )
                            val intent =
                                Intent(Intent.ACTION_VIEW).apply {
                                    setDataAndType(
                                        uri,
                                        "application/vnd.android.package-archive",
                                    )
                                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                                    addFlags(
                                        Intent.FLAG_GRANT_READ_URI_PERMISSION,
                                    )
                                }
                            startActivity(intent)
                            result.success(true)
                        } catch (e: Exception) {
                            result.success(false)
                        }
                    }

                    "uninstallSelf" -> {
                        try {
                            val intent = Intent(
                                Intent.ACTION_DELETE,
                                Uri.parse("package:$packageName"),
                            )
                            startActivity(intent)
                            result.success(true)
                        } catch (e: Exception) {
                            result.success(false)
                        }
                    }

                    else -> result.notImplemented()
                }
            }
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(
            requestCode,
            permissions,
            grantResults,
        )
        if (requestCode == REQUEST_STORAGE) {
            val granted = grantResults.isNotEmpty() &&
                grantResults[0] == PackageManager.PERMISSION_GRANTED
            pendingPermissionResult?.success(granted)
            pendingPermissionResult = null
        }
    }

    private fun hasStoragePermission(): Boolean {
        if (Build.VERSION.SDK_INT < 23) return true
        return androidx.core.content.ContextCompat.checkSelfPermission(
            this,
            Manifest.permission.WRITE_EXTERNAL_STORAGE,
        ) == PackageManager.PERMISSION_GRANTED
    }

    private fun signingFlags(): Int {
        return if (Build.VERSION.SDK_INT >= 28) {
            PackageManager.GET_SIGNING_CERTIFICATES
        } else {
            @Suppress("DEPRECATION")
            PackageManager.GET_SIGNATURES
        }
    }

    private fun versionCodeOf(
        info: android.content.pm.PackageInfo,
    ): Long {
        return if (Build.VERSION.SDK_INT >= 28) {
            info.longVersionCode
        } else {
            @Suppress("DEPRECATION")
            info.versionCode.toLong()
        }
    }

    private fun firstSignature(
        info: android.content.pm.PackageInfo?,
    ): ByteArray? {
        if (info == null) return null
        return if (Build.VERSION.SDK_INT >= 28) {
            val signingInfo = info.signingInfo ?: return null
            val certs = if (signingInfo.hasMultipleSigners()) {
                signingInfo.apkContentsSigners
            } else {
                signingInfo.signingCertificateHistory
            }
            certs?.firstOrNull()?.toByteArray()
        } else {
            @Suppress("DEPRECATION")
            info.signatures?.firstOrNull()?.toByteArray()
        }
    }
}
