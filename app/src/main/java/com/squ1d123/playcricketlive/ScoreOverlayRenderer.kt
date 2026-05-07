package com.squ1d123.playcricketlive

import android.graphics.*

class ScoreOverlayRenderer(private val streamWidth: Int, private val streamHeight: Int) {

    private val overlayHeight = (streamHeight * 0.08f).toInt()

    private val bgPaint = Paint().apply { color = Color.argb(220, 0, 0, 0); style = Paint.Style.FILL }
    private val whitePaint = Paint().apply { color = Color.WHITE; isAntiAlias = true; typeface = Typeface.DEFAULT_BOLD }
    private val greenPaint = Paint().apply { color = Color.rgb(76, 175, 80); isAntiAlias = true; typeface = Typeface.DEFAULT_BOLD }
    private val redPaint = Paint().apply { color = Color.rgb(244, 67, 54); isAntiAlias = true; typeface = Typeface.DEFAULT_BOLD }
    private val dimPaint = Paint().apply { color = Color.argb(180, 255, 255, 255); isAntiAlias = true }

    fun render(
        batsman1Name: String, batsman1Runs: Int, batsman1Balls: Int,
        batsman2Name: String, batsman2Runs: Int, batsman2Balls: Int,
        score: String, overs: String,
        bowlerName: String, bowlerWickets: Int, bowlerRuns: Int, bowlerOvers: Int,
    ): Bitmap {
        val bitmap = Bitmap.createBitmap(streamWidth, overlayHeight, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)
        canvas.drawRect(0f, 0f, streamWidth.toFloat(), overlayHeight.toFloat(), bgPaint)

        val fontSize = overlayHeight * 0.35f
        val bigFontSize = overlayHeight * 0.5f
        val smallFontSize = overlayHeight * 0.28f
        val padding = streamWidth * 0.02f
        val yCenter = overlayHeight / 2f + fontSize * 0.35f

        // Left: Batsmen
        whitePaint.textSize = fontSize
        greenPaint.textSize = fontSize
        var x = padding
        if (batsman1Name.isNotEmpty()) {
            canvas.drawText(batsman1Name, x, yCenter, whitePaint)
            x += whitePaint.measureText(batsman1Name) + padding * 0.5f
            val b1 = "$batsman1Runs($batsman1Balls)"
            canvas.drawText(b1, x, yCenter, greenPaint)
            x += greenPaint.measureText(b1) + padding
        }
        if (batsman2Name.isNotEmpty()) {
            dimPaint.textSize = fontSize * 0.85f
            canvas.drawText(batsman2Name, x, yCenter, dimPaint)
            x += dimPaint.measureText(batsman2Name) + padding * 0.5f
            val b2 = "$batsman2Runs($batsman2Balls)"
            canvas.drawText(b2, x, yCenter, dimPaint)
        }

        // Center: Score
        whitePaint.textSize = bigFontSize
        whitePaint.textAlign = Paint.Align.CENTER
        canvas.drawText(score, streamWidth / 2f, yCenter, whitePaint)
        if (overs.isNotEmpty()) {
            dimPaint.textSize = smallFontSize
            dimPaint.textAlign = Paint.Align.CENTER
            canvas.drawText("$overs ov", streamWidth / 2f, yCenter + smallFontSize * 1.2f, dimPaint)
            dimPaint.textAlign = Paint.Align.LEFT
        }
        whitePaint.textAlign = Paint.Align.LEFT

        // Right: Bowler
        if (bowlerName.isNotEmpty()) {
            whitePaint.textSize = fontSize
            redPaint.textSize = fontSize
            redPaint.textAlign = Paint.Align.RIGHT
            whitePaint.textAlign = Paint.Align.RIGHT

            val rightEdge = streamWidth - padding
            val stats = "$bowlerWickets/$bowlerRuns ($bowlerOvers)"
            canvas.drawText(stats, rightEdge, yCenter, redPaint)
            val statsW = redPaint.measureText(stats)
            canvas.drawText(bowlerName, rightEdge - statsW - padding * 0.5f, yCenter, whitePaint)

            whitePaint.textAlign = Paint.Align.LEFT
            redPaint.textAlign = Paint.Align.LEFT
        }

        return bitmap
    }

    fun getScaleY(): Float = (overlayHeight.toFloat() / streamHeight) * 100f
}
