package com.squ1d123.playcricketlive

import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import okhttp3.OkHttpClient
import okhttp3.Request
import org.json.JSONArray
import org.json.JSONObject
import java.util.Base64
import javax.crypto.Cipher
import javax.crypto.SecretKeyFactory
import javax.crypto.spec.DESedeKeySpec

data class MatchData(
    val rvMatchId: Int = 0,
    val homeTeam: String = "",
    val homeScore: String = "",
    val homeOvers: String = "",
    val awayTeam: String = "",
    val awayScore: String = "",
    val awayOvers: String = "",
    val result: String = "",
    val batsmen: List<BatsmanData> = emptyList(),
    val bowlers: List<BowlerData> = emptyList(),
    val battingTeam: String = "",
    val battingScore: String = "",
    val battingOvers: String = "",
    val bowlingTeam: String = "",
    val bowlingInningsNumber: Int = 0,
    val bowlingResultId: Int? = null,
    val targetScore: String = "",
)

data class BatsmanData(val name: String, val runs: Int, val balls: Int, val notOut: Boolean = false)
data class BowlerData(val bowlerId: Int? = null, val name: String, val wickets: Int, val runs: Int, val overs: Int)

class PlayCricketScraper(private val client: OkHttpClient = OkHttpClient()) {

    companion object {
        private const val API_BASE = "https://api.resultsvault.co.uk/rv/"
        private const val API_ID = "1003"
        private const val SHARED_SECRET = "5BD4A72CE1934BA5A629CD98"
        private const val MASTER_ENTITY_ID = "130000"

        fun extractMatchId(url: String): Int? {
            val match = Regex("""/results/(\d+)""").find(url)
            return match?.groupValues?.get(1)?.toIntOrNull()
        }
    }

    private fun generateToken(): String {
        val timestamp = (System.currentTimeMillis() / 1000 - 60).toString()
        val input = timestamp.toByteArray(Charsets.US_ASCII).toMutableList()
        val padLen = 8 - (input.size % 8)
        repeat(padLen) { input.add(padLen.toByte()) }

        val keyBytes = SHARED_SECRET.toByteArray(Charsets.US_ASCII)
        val keySpec = DESedeKeySpec(keyBytes)
        val keyFactory = SecretKeyFactory.getInstance("DESede")
        val secretKey = keyFactory.generateSecret(keySpec)

        val cipher = Cipher.getInstance("DESede/ECB/NoPadding")
        cipher.init(Cipher.ENCRYPT_MODE, secretKey)
        val encrypted = cipher.doFinal(input.toByteArray())
        return Base64.getEncoder().encodeToString(encrypted)
    }

    private fun buildRequest(url: String): Request {
        return Request.Builder()
            .url(url)
            .header("accept", "application/json")
            .header("Content-Type", "application/json")
            .header("origin", "https://play-cricket.com")
            .header("referer", "https://play-cricket.com/")
            .header("x-ias-api-request", generateToken())
            .build()
    }

    private suspend fun getResultsVaultMatchId(externalMatchId: Int): Int? = withContext(Dispatchers.IO) {
        val url = "${API_BASE}mappings/4/12/$externalMatchId/?apiid=$API_ID&sportid=1"
        val response = client.newCall(buildRequest(url)).execute()
        if (!response.isSuccessful) return@withContext null
        val json = JSONObject(response.body?.string() ?: return@withContext null)
        json.optInt("object_id1", 0).takeIf { it != 0 }
    }

    suspend fun fetchMatchData(playCricketUrl: String): MatchData? = withContext(Dispatchers.IO) {
        val externalId = extractMatchId(playCricketUrl) ?: return@withContext null
        val rvMatchId = getResultsVaultMatchId(externalId) ?: return@withContext null

        val url = "${API_BASE}$MASTER_ENTITY_ID/matches/$rvMatchId/?apiid=$API_ID&strmflg=3"
        val response = client.newCall(buildRequest(url)).execute()
        if (!response.isSuccessful) return@withContext null
        val json = JSONObject(response.body?.string() ?: return@withContext null)
        parseMatchData(json, rvMatchId)
    }

    suspend fun fetchCurrentBowler(matchData: MatchData): BowlerData? = withContext(Dispatchers.IO) {
        if (matchData.rvMatchId == 0 || matchData.bowlingInningsNumber == 0 || matchData.bowlingResultId == null) return@withContext null

        val url = "${API_BASE}$MASTER_ENTITY_ID/matches/${matchData.rvMatchId}/?apiid=$API_ID&action=getballs&sportid=1&resultid=${matchData.bowlingResultId}&inningsnumber=${matchData.bowlingInningsNumber}"
        val response = client.newCall(buildRequest(url)).execute()
        if (!response.isSuccessful) return@withContext null
        val body = response.body?.string() ?: return@withContext null
        parseCurrentBowler(body, matchData.bowlers)
    }

    private fun parseCurrentBowler(body: String, bowlers: List<BowlerData>): BowlerData? {
        val balls: JSONArray = try {
            val json = JSONObject(body)
            json.optJSONArray("BallbyBall") ?: json.optJSONArray("balls") ?: return null
        } catch (_: Exception) {
            try { JSONArray(body) } catch (_: Exception) { return null }
        }
        if (balls.length() == 0) return null

        val lastBall = balls.getJSONObject(balls.length() - 1)
        val bowlerId = lastBall.optInt("bowler_id", 0).takeIf { it != 0 } ?: return null

        var name = lastBall.optString("bowler_name", "").ifEmpty { lastBall.optString("bowler", "") }
        var overs = 0; var runs = 0; var wickets = 0

        if (name.isEmpty()) {
            val matched = bowlers.find { it.bowlerId == bowlerId }
            if (matched != null) {
                name = matched.name; overs = matched.overs; runs = matched.runs; wickets = matched.wickets
            } else {
                name = "Bowler $bowlerId"
            }
        }

        return BowlerData(bowlerId = bowlerId, name = name, wickets = wickets, runs = runs, overs = overs)
    }

    private fun parseMatchData(data: JSONObject, rvMatchId: Int): MatchData {
        val teams = data.optJSONArray("MatchTeams") ?: return MatchData(
            rvMatchId = rvMatchId,
            homeTeam = data.optString("home_name", ""),
            awayTeam = data.optString("away_name", ""),
            result = data.optString("leader_text", "")
        )
        if (teams.length() == 0) return MatchData(rvMatchId = rvMatchId)

        val homeTeam = (0 until teams.length()).map { teams.getJSONObject(it) }.firstOrNull { it.optBoolean("is_home", false) } ?: teams.getJSONObject(0)
        val awayTeam = (0 until teams.length()).map { teams.getJSONObject(it) }.firstOrNull { !it.optBoolean("is_home", true) } ?: if (teams.length() > 1) teams.getJSONObject(1) else teams.getJSONObject(0)

        val homeInnings = parseInnings(homeTeam)
        val awayInnings = parseInnings(awayTeam)
        val homeBattedFirst = homeTeam.optBoolean("batted_first", false)
        val homeRuns = getInningsRuns(homeTeam)
        val awayRuns = getInningsRuns(awayTeam)

        val battingTeamJson: JSONObject
        val battingInnings: Pair<String, String>
        val bowlingTeamName: String
        val bowlingInningsNum: Int
        val bowlingResultId: Int?

        if (homeBattedFirst) {
            if (awayRuns > 0) {
                battingTeamJson = awayTeam; battingInnings = awayInnings; bowlingTeamName = homeTeam.optString("club_name", "")
                bowlingInningsNum = getInningsNumber(awayTeam); bowlingResultId = awayTeam.optInt("result_id", 0).takeIf { it != 0 }
            } else {
                battingTeamJson = homeTeam; battingInnings = homeInnings; bowlingTeamName = awayTeam.optString("club_name", "")
                bowlingInningsNum = getInningsNumber(homeTeam); bowlingResultId = homeTeam.optInt("result_id", 0).takeIf { it != 0 }
            }
        } else {
            if (homeRuns > 0) {
                battingTeamJson = homeTeam; battingInnings = homeInnings; bowlingTeamName = awayTeam.optString("club_name", "")
                bowlingInningsNum = getInningsNumber(homeTeam); bowlingResultId = homeTeam.optInt("result_id", 0).takeIf { it != 0 }
            } else {
                battingTeamJson = awayTeam; battingInnings = awayInnings; bowlingTeamName = homeTeam.optString("club_name", "")
                bowlingInningsNum = getInningsNumber(awayTeam); bowlingResultId = awayTeam.optInt("result_id", 0).takeIf { it != 0 }
            }
        }

        val batsmen = parseBatsmen(battingTeamJson)
        val bowlers = parseBowlers(battingTeamJson)

        val isSecondInnings = if (homeBattedFirst) awayRuns > 0 else homeRuns > 0
        val targetScore = if (isSecondInnings) {
            val firstInningsRuns = if (homeBattedFirst) getFirstInningsRuns(homeTeam) else getFirstInningsRuns(awayTeam)
            "Target: ${firstInningsRuns + 1}"
        } else ""

        return MatchData(
            rvMatchId = rvMatchId,
            homeTeam = homeTeam.optString("club_name", ""),
            homeScore = homeInnings.first, homeOvers = homeInnings.second,
            awayTeam = awayTeam.optString("club_name", ""),
            awayScore = awayInnings.first, awayOvers = awayInnings.second,
            result = data.optString("leader_text", ""),
            batsmen = batsmen, bowlers = bowlers,
            battingTeam = battingTeamJson.optString("club_name", ""),
            battingScore = battingInnings.first, battingOvers = battingInnings.second,
            bowlingTeam = bowlingTeamName,
            bowlingInningsNumber = bowlingInningsNum, bowlingResultId = bowlingResultId,
            targetScore = targetScore,
        )
    }

    private fun getFirstInningsRuns(team: JSONObject): Int {
        val innings = team.optJSONArray("Innings") ?: return 0
        if (innings.length() == 0) return 0
        return innings.getJSONObject(0).optInt("runs", 0)
    }

    private fun getInningsRuns(team: JSONObject): Int {
        val innings = team.optJSONArray("Innings") ?: return 0
        if (innings.length() == 0) return 0
        return innings.getJSONObject(innings.length() - 1).optInt("runs", 0)
    }

    private fun getInningsNumber(team: JSONObject): Int {
        val innings = team.optJSONArray("Innings") ?: return 1
        if (innings.length() == 0) return 1
        val inn = innings.getJSONObject(innings.length() - 1)
        return inn.optInt("innings_number", inn.optInt("innings_order", inn.optInt("id", 1)))
    }

    private fun parseInnings(team: JSONObject): Pair<String, String> {
        val innings = team.optJSONArray("Innings")
        if (innings == null || innings.length() == 0) {
            val scoreText = team.optString("match_score_text", "")
            val match = Regex("""(\d+)/(\d+)""").find(scoreText)
            return if (match != null) "${match.groupValues[2]}/${match.groupValues[1]}" to "" else "" to ""
        }
        val inn = innings.getJSONObject(innings.length() - 1)
        val runs = inn.optInt("runs", 0)
        val wickets = inn.optInt("wickets", 0)
        val overs = inn.optString("overs_bowled", "")
        return "$runs/$wickets" to overs
    }

    private fun parseBatsmen(team: JSONObject): List<BatsmanData> {
        val innings = team.optJSONArray("Innings") ?: return emptyList()
        if (innings.length() == 0) return emptyList()
        val perfs = innings.getJSONObject(innings.length() - 1).optJSONArray("PlayerPerfs") ?: return emptyList()
        return (0 until perfs.length())
            .map { perfs.getJSONObject(it) }
            .filter { it.optString("__type") == "Batting:http://api.resultsvault.com" && it.optInt("dismissal_id") == 1 }
            .map { BatsmanData(name = it.optString("player_name", ""), runs = it.optInt("runs", 0), balls = it.optInt("balls", 0), notOut = true) }
    }

    private fun parseBowlers(team: JSONObject): List<BowlerData> {
        val innings = team.optJSONArray("Innings") ?: return emptyList()
        if (innings.length() == 0) return emptyList()
        val perfs = innings.getJSONObject(innings.length() - 1).optJSONArray("PlayerPerfs") ?: return emptyList()
        return (0 until perfs.length())
            .map { perfs.getJSONObject(it) }
            .filter { it.optString("__type") == "Bowling:http://api.resultsvault.com" }
            .map {
                BowlerData(
                    bowlerId = it.optInt("player_id", it.optInt("id", 0)).takeIf { id -> id != 0 },
                    name = it.optString("player_name", ""),
                    wickets = it.optInt("wickets", 0),
                    runs = it.optInt("runs", 0),
                    overs = it.optInt("overs", 0)
                )
            }
    }
}
