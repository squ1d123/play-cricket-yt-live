package com.squ1d123.playcricketlive

import org.junit.Assert.*
import org.junit.Test

class PlayCricketScraperTest {

    @Test
    fun `extractMatchId extracts ID from play-cricket URL`() {
        val url = "https://debeauvoirdugongs.play-cricket.com/website/results/7080352"
        assertEquals(7080352, PlayCricketScraper.extractMatchId(url))
    }

    @Test
    fun `extractMatchId returns null for invalid URL`() {
        assertNull(PlayCricketScraper.extractMatchId("https://example.com/not-a-match"))
    }

    @Test
    fun `extractMatchId returns null for URL without ID`() {
        assertNull(PlayCricketScraper.extractMatchId("https://play-cricket.com/website/results/"))
    }
}
