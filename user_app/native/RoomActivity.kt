package com.onyx.user_app

import android.Manifest
import android.annotation.SuppressLint
import android.app.Activity
import android.content.Intent
import android.content.pm.ActivityInfo
import android.content.pm.PackageManager
import android.graphics.Color
import android.graphics.Rect
import android.graphics.drawable.GradientDrawable
import android.net.Uri
import android.os.Bundle
import android.view.Gravity
import android.view.View
import android.webkit.CookieManager
import android.webkit.JavascriptInterface
import android.webkit.PermissionRequest
import android.webkit.ValueCallback
import android.webkit.WebChromeClient
import android.webkit.WebResourceRequest
import android.webkit.WebResourceResponse
import android.webkit.WebView
import android.webkit.WebViewClient
import android.widget.FrameLayout
import android.widget.LinearLayout
import android.widget.TextView
import androidx.webkit.WebViewAssetLoader
import org.json.JSONObject

class RoomActivity : Activity() {
    private lateinit var root: FrameLayout
    private lateinit var ui: WebView
    private lateinit var br: WebView
    private lateinit var exitBtn: TextView
    private var last = ""
    private var picker: ValueCallback<Array<Uri>>? = null
    private var fs = false
    private var cv: View? = null
    private var cvCb: WebChromeClient.CustomViewCallback? = null
    private val rect = DoubleArray(4)
    private var pendingPerm: PermissionRequest? = null
    private lateinit var bar: LinearLayout
    private var kbOpen = false

    // ONYX bottom bar: index must match the Flutter NavigationBar order
    private val tabs = arrayOf("🏠" to "Home", "💬" to "Chats", "🎤" to "Rooms", "➕" to "Add", "👤" to "Profile", "⚙" to "More")

    private fun dp(v: Int) = (v * resources.displayMetrics.density).toInt()
    private fun col(key: String, def: Int): Int =
        try { Color.parseColor(intent.getStringExtra(key)) } catch (e: Exception) { def }

    private fun buildBar() {
        val navBg = col("navBg", 0xFF1D1B20.toInt())
        val navFg = col("navFg", 0xFFCAC4D0.toInt())
        val navSel = col("navSel", 0xFFFFFFFF.toInt())
        val ind = col("ind", 0xFF4A4458.toInt())
        bar = LinearLayout(this)
        bar.orientation = LinearLayout.HORIZONTAL
        bar.setBackgroundColor(navBg)
        tabs.forEachIndexed { i, p ->
            val cell = LinearLayout(this)
            cell.orientation = LinearLayout.VERTICAL
            cell.gravity = Gravity.CENTER
            cell.setPadding(0, dp(10), 0, dp(10))
            val ic = TextView(this)
            ic.text = p.first
            ic.textSize = 18f
            ic.gravity = Gravity.CENTER
            ic.setPadding(dp(18), dp(3), dp(18), dp(3))
            if (i == 2) {
                val g = GradientDrawable()
                g.cornerRadius = dp(16).toFloat()
                g.setColor(ind)
                ic.background = g
            }
            val lb = TextView(this)
            lb.text = p.second
            lb.textSize = 11f
            lb.gravity = Gravity.CENTER
            lb.setTextColor(if (i == 2) navSel else navFg)
            cell.addView(ic)
            cell.addView(lb)
            cell.setOnClickListener { if (i != 2) finishTab(i) }
            bar.addView(cell, LinearLayout.LayoutParams(0, -2, 1f))
        }
    }

    private fun updBar() {
        bar.visibility = if (fs || cv != null || kbOpen) View.GONE else View.VISIBLE
    }

    @Suppress("DEPRECATION")
    private fun finishTab(t: Int) {
        setResult(RESULT_OK, Intent().putExtra("tab", t))
        finish()
        overridePendingTransition(0, 0)
    }

    private val syncJs = """(function(){if(window.__sy)return;window.__sy=1;var ap=false;
function V(){return document.querySelector('video')}
function ev(t){var v=V();if(v&&!ap)B.evt(t,v.currentTime)}
document.addEventListener('play',function(){ev('play')},true);
document.addEventListener('pause',function(){ev('pause')},true);
document.addEventListener('seeked',function(){ev('seek')},true);
window.__cmd=function(p,t){var v=V();if(!v)return;ap=true;if(Math.abs(v.currentTime-t)>1.5)v.currentTime=t;if(p){v.play()}else{v.pause()};setTimeout(function(){ap=false},1200)}})();"""

    @SuppressLint("SetJavaScriptEnabled", "JavascriptInterface")
    override fun onCreate(b: Bundle?) {
        super.onCreate(b)
        root = FrameLayout(this)
        root.setBackgroundColor(col("bg", Color.BLACK))
        setContentView(root)
        val loader = WebViewAssetLoader.Builder()
            .addPathHandler("/assets/", WebViewAssetLoader.AssetsPathHandler(this)).build()

        ui = WebView(this)
        ui.setBackgroundColor(col("bg", Color.BLACK))
        ui.settings.javaScriptEnabled = true
        ui.settings.domStorageEnabled = true
        ui.settings.mediaPlaybackRequiresUserGesture = false
        ui.webViewClient = object : WebViewClient() {
            override fun shouldInterceptRequest(view: WebView, request: WebResourceRequest): WebResourceResponse? =
                loader.shouldInterceptRequest(request.url)

            override fun shouldOverrideUrlLoading(view: WebView, request: WebResourceRequest): Boolean {
                if (request.url.host == "appassets.androidplatform.net") return false
                try { startActivity(Intent(Intent.ACTION_VIEW, request.url)) } catch (e: Exception) {}
                return true
            }
        }
        ui.webChromeClient = object : WebChromeClient() {
            override fun onPermissionRequest(req: PermissionRequest) {
                runOnUiThread {
                    if (checkSelfPermission(Manifest.permission.RECORD_AUDIO) == PackageManager.PERMISSION_GRANTED) {
                        req.grant(arrayOf(PermissionRequest.RESOURCE_AUDIO_CAPTURE))
                    } else {
                        pendingPerm = req
                        requestPermissions(arrayOf(Manifest.permission.RECORD_AUDIO), 11)
                    }
                }
            }

            override fun onShowFileChooser(w: WebView, cb: ValueCallback<Array<Uri>>, p: FileChooserParams): Boolean {
                picker?.onReceiveValue(null)
                picker = cb
                val wantVideo = p.acceptTypes.joinToString(",").contains("video")
                val i = Intent(Intent.ACTION_GET_CONTENT)
                i.addCategory(Intent.CATEGORY_OPENABLE)
                i.type = "*/*"
                i.putExtra(Intent.EXTRA_MIME_TYPES, if (wantVideo) arrayOf("image/*", "video/*") else arrayOf("image/*"))
                startActivityForResult(i, 7)
                return true
            }
        }
        ui.addJavascriptInterface(UiBridge(), "Android")

        br = WebView(this)
        br.settings.javaScriptEnabled = true
        br.settings.domStorageEnabled = true
        br.settings.mediaPlaybackRequiresUserGesture = false
        CookieManager.getInstance().setAcceptThirdPartyCookies(br, true)
        br.addJavascriptInterface(BrBridge(), "B")
        br.webChromeClient = object : WebChromeClient() {
            override fun onShowCustomView(v: View, cb: CustomViewCallback) {
                if (cv != null) { cb.onCustomViewHidden(); return }
                cv = v
                cvCb = cb
                root.addView(v, FrameLayout.LayoutParams(-1, -1))
                updBar()
                immersive(true)
                requestedOrientation = ActivityInfo.SCREEN_ORIENTATION_SENSOR_LANDSCAPE
            }

            override fun onHideCustomView() { hideCv() }
        }
        br.webViewClient = object : WebViewClient() {
            override fun doUpdateVisitedHistory(view: WebView, url: String, isReload: Boolean) { nav(url) }
            override fun onPageFinished(view: WebView, url: String) { view.evaluateJavascript(syncJs, null) }
            override fun shouldOverrideUrlLoading(view: WebView, request: WebResourceRequest): Boolean {
                val s = request.url.scheme
                return !(s == "http" || s == "https")
            }
        }
        br.visibility = View.GONE

        exitBtn = TextView(this)
        exitBtn.text = "✕"
        exitBtn.textSize = 20f
        exitBtn.setTextColor(Color.WHITE)
        exitBtn.setBackgroundColor(0x99000000.toInt())
        exitBtn.setPadding(36, 20, 36, 20)
        exitBtn.visibility = View.GONE
        exitBtn.setOnClickListener { setFull(false) }

        buildBar()
        val main = LinearLayout(this)
        main.orientation = LinearLayout.VERTICAL
        main.addView(ui, LinearLayout.LayoutParams(-1, 0, 1f))
        main.addView(bar, LinearLayout.LayoutParams(-1, -2))
        root.addView(main, FrameLayout.LayoutParams(-1, -1))
        root.addView(br, FrameLayout.LayoutParams(1, 1))
        root.addView(exitBtn, FrameLayout.LayoutParams(-2, -2, Gravity.TOP or Gravity.END))
        @Suppress("DEPRECATION")
        root.setOnApplyWindowInsetsListener { _, ins ->
            bar.setPadding(0, 0, 0, ins.systemWindowInsetBottom)
            ins
        }
        root.viewTreeObserver.addOnGlobalLayoutListener {
            val r = Rect()
            root.getWindowVisibleDisplayFrame(r)
            val open = root.rootView.height - r.bottom > dp(150)
            if (open != kbOpen) { kbOpen = open; updBar() }
        }
        ui.loadUrl("https://appassets.androidplatform.net/assets/app.html")
    }

    @Suppress("DEPRECATION")
    private fun immersive(on: Boolean) {
        window.decorView.systemUiVisibility = if (on) (View.SYSTEM_UI_FLAG_FULLSCREEN or
            View.SYSTEM_UI_FLAG_HIDE_NAVIGATION or View.SYSTEM_UI_FLAG_IMMERSIVE_STICKY or
            View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN or View.SYSTEM_UI_FLAG_LAYOUT_HIDE_NAVIGATION or
            View.SYSTEM_UI_FLAG_LAYOUT_STABLE) else View.SYSTEM_UI_FLAG_VISIBLE
    }

    private fun applyRect() {
        val d = resources.displayMetrics.density
        val lp = FrameLayout.LayoutParams((rect[2] * d).toInt(), (rect[3] * d).toInt(), Gravity.TOP or Gravity.START)
        lp.leftMargin = (rect[0] * d).toInt()
        lp.topMargin = (rect[1] * d).toInt()
        br.layoutParams = lp
    }

    private fun setFull(on: Boolean) {
        fs = on
        updBar()
        if (on) {
            br.layoutParams = FrameLayout.LayoutParams(-1, -1)
            br.visibility = View.VISIBLE
            exitBtn.visibility = View.VISIBLE
            immersive(true)
            requestedOrientation = ActivityInfo.SCREEN_ORIENTATION_SENSOR_LANDSCAPE
        } else {
            exitBtn.visibility = View.GONE
            applyRect()
            if (cv == null) {
                immersive(false)
                requestedOrientation = ActivityInfo.SCREEN_ORIENTATION_UNSPECIFIED
            }
        }
    }

    private fun hideCv() {
        val v = cv ?: return
        root.removeView(v)
        cv = null
        cvCb?.onCustomViewHidden()
        cvCb = null
        updBar()
        if (!fs) {
            immersive(false)
            requestedOrientation = ActivityInfo.SCREEN_ORIENTATION_UNSPECIFIED
        }
    }

    private fun nav(url: String?) {
        if (url == null || !url.startsWith("http") || url == last) return
        last = url
        ui.evaluateJavascript("window.onBrowserNav&&onBrowserNav(" + JSONObject.quote(url) + ")", null)
    }

    inner class UiBridge {
        @JavascriptInterface
        fun cfg(): String {
            val o = JSONObject()
            fun put(k: String, ek: String = k) { intent.getStringExtra(ek)?.let { o.put(k, it) } }
            put("email"); put("pass"); put("username"); put("photo")
            put("bg"); put("card"); put("tx"); put("ac"); put("mut"); put("onac")
            return o.toString()
        }

        @JavascriptInterface
        fun setRect(x: Double, y: Double, w: Double, h: Double) = runOnUiThread {
            rect[0] = x; rect[1] = y; rect[2] = w; rect[3] = h
            if (!fs) applyRect()
        }

        @JavascriptInterface
        fun show(v: Boolean) = runOnUiThread {
            if (!fs) br.visibility = if (v) View.VISIBLE else View.GONE
        }

        @JavascriptInterface
        fun full(on: Boolean) = runOnUiThread { setFull(on) }

        @JavascriptInterface
        fun load(u: String) = runOnUiThread {
            if (u.startsWith("http://") || u.startsWith("https://")) {
                last = u
                br.loadUrl(u)
            }
        }

        @JavascriptInterface
        fun cmd(p: Boolean, t: Double) = runOnUiThread {
            if (!t.isNaN() && !t.isInfinite()) br.evaluateJavascript("window.__cmd&&__cmd($p,$t)", null)
        }

        @JavascriptInterface
        fun back() = runOnUiThread { if (br.canGoBack()) br.goBack() }

        @JavascriptInterface
        fun share(t: String) = runOnUiThread {
            val i = Intent(Intent.ACTION_SEND)
            i.type = "text/plain"
            i.putExtra(Intent.EXTRA_TEXT, t)
            startActivity(Intent.createChooser(i, "Invite"))
        }
    }

    inner class BrBridge {
        @JavascriptInterface
        fun evt(type: String, t: Double) = runOnUiThread {
            if ((type == "play" || type == "pause" || type == "seek") && !t.isNaN() && !t.isInfinite()) {
                ui.evaluateJavascript("window.onVideoEvt&&onVideoEvt('$type',$t)", null)
            }
        }
    }

    override fun onRequestPermissionsResult(code: Int, perms: Array<out String>, res: IntArray) {
        super.onRequestPermissionsResult(code, perms, res)
        if (code == 11) {
            val r = pendingPerm
            pendingPerm = null
            if (r != null) {
                if (res.isNotEmpty() && res[0] == PackageManager.PERMISSION_GRANTED) {
                    r.grant(arrayOf(PermissionRequest.RESOURCE_AUDIO_CAPTURE))
                } else {
                    r.deny()
                }
            }
        }
    }

    @Suppress("DEPRECATION")
    override fun onActivityResult(rc: Int, res: Int, d: Intent?) {
        if (rc == 7) {
            val u = d?.data
            picker?.onReceiveValue(if (res == RESULT_OK && u != null) arrayOf(u) else null)
            picker = null
        } else super.onActivityResult(rc, res, d)
    }

    @Suppress("DEPRECATION")
    override fun onBackPressed() {
        when {
            cv != null -> hideCv()
            fs -> setFull(false)
            br.visibility == View.VISIBLE && br.canGoBack() -> br.goBack()
            else -> ui.evaluateJavascript("(typeof cur!=='undefined'&&cur)?(leave(),1):0") { r ->
                if (r != "1") finishTab(-1)
            }
        }
    }
}
