--different types of columns in table “ball_by_ball” 
USE ipl;
SELECT COLUMN_NAME, DATA_TYPE
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME = 'ball_by_ball';

--total number of runs scored in 1st season by RCB 
SELECT
    SUM(b.Runs_Scored + COALESCE(e.Extra_Runs, 0)) AS Total_Runs
FROM ball_by_ball b
JOIN matches m ON b.Match_Id = m.Match_Id
JOIN team t ON b.Team_Batting = t.Team_Id
LEFT JOIN extra_runs e
    ON b.Match_Id = e.Match_Id
    AND b.Over_Id = e.Over_Id
    AND b.Ball_Id = e.Ball_Id
    AND b.Innings_No = e.Innings_No
WHERE m.Season_Id = 1
    AND t.Team_Name = "Royal Challengers Bangalore";

--players were more than the age of 25 during season 2014
SELECT
    COUNT(DISTINCT p.Player_Id) AS Players_Above_25
FROM
    Player p
JOIN
    Player_Match pm ON p.Player_Id = pm.Player_Id
JOIN
    Matches m ON pm.Match_Id = m.Match_Id
JOIN
    Season s ON m.Season_Id = s.Season_Id
WHERE
    s.Season_Year = 2014
    AND TIMESTAMPDIFF(YEAR, p.DOB, '2014-01-01') > 25;

--matches RCB won in 2013
SELECT
    COUNT(*) AS Matches_Won_By_RCB
FROM
    Matches m
JOIN
    Season s ON m.Season_Id = s.Season_Id
WHERE
    s.Season_Year = 2013
    AND m.Match_Winner = (
        SELECT Team_Id
        FROM Team
        WHERE Team_Name = 'Royal Challengers Bangalore'
    );

--top 10 players according to their strike rate in the last 4 seasons
SELECT
    p.Player_Name,
    ROUND(SUM(b.Runs_Scored) * 100.0 / COUNT(b.Ball_Id), 2) AS Strike_Rate
FROM
    Ball_by_Ball b
JOIN Matches m ON b.Match_Id = m.Match_Id
JOIN Season s ON m.Season_Id = s.Season_Id
JOIN Player p ON b.Striker = p.Player_Id
WHERE
    s.Season_Year >= (
        SELECT MAX(Season_Year) - 3
        FROM Season
    )
GROUP BY
    p.Player_Id
HAVING
    COUNT(b.Ball_Id) >= 10 -- optional: avoid very low ball counts
ORDER BY
    Strike_Rate DESC
LIMIT 10;

--average runs scored by each batsman considering all the seasons
WITH player_runs AS (
SELECT
		Striker AS Player_Id,
		SUM(Runs_Scored) AS Total_Runs
FROM Ball_by_Ball	
GROUP BY triker
),
player_innings AS (
SELECT
		Striker AS Player_Id,
COUNT(DISTINCT CONCAT(Match_Id, '-', Innings_No)) AS Innings_Played
FROM Ball_by_Ball	
GROUP BY Striker
)
SELECT
		p.Player_Name,
		r.Total_Runs,
		i.Innings_Played,
ROUND(r.Total_Runs * 1.0 / i.Innings_Played, 2) AS Avg_Runs
FROM player_runs r
JOIN player_innings i ON r.Player_Id = i.Player_Id
JOIN Player p ON p.Player_Id = r.Player_Id
ORDER BY Avg_Runs DESC;


--the average wickets taken by each bowler considering all the seasons
WITH bowler_wickets AS (
SELECT
b.Bowler AS Player_Id,
COUNT(w.Player_Out) AS Total_Wickets
FROM Ball_by_Ball b
JOIN Wicket_Taken w ON b.Match_Id = w.Match_Id
AND b.Over_Id = w.Over_Id
AND b.Ball_Id = w.Ball_Id
AND b.Innings_No = w.Innings_No
GROUP BY b.Bowler
),
bowler_innings AS (
SELECT
Bowler AS Player_Id,
COUNT(DISTINCT CONCAT(Match_Id, '-', Innings_No)) AS Innings_Bowled
FROM Ball_by_Ball
GROUP BY Bowler
)
SELECT
p.Player_Name,
w.Total_Wickets,
i.Innings_Bowled,
ROUND(w.Total_Wickets * 1.0 / i.Innings_Bowled, 2) AS Avg_Wickets
FROM bowler_wickets w
JOIN bowler_innings i ON w.Player_Id = i.Player_Id
JOIN	 Player p ON p.Player_Id = w.Player_Id
ORDER BY Avg_Wickets DESC;


--all the players who have average runs scored greater than the overall average and who have taken wickets greater than the overall average
WITH player_runs AS (
SELECT
	Striker AS Player_Id,
	SUM(Runs_Scored) AS Total_Runs,
	COUNT(DISTINCT CONCAT(Match_Id, '-', Innings_No)) AS Innings_Played
FROM Ball_by_Ball
GROUP BY Striker
),
player_avg_runs AS (
SELECT
	Player_Id,
	ROUND(Total_Runs * 1.0 / Innings_Played, 2) AS Avg_Runs
FROM player_runs
WHERE Innings_Played > 0
),
overall_avg_runs AS (
SELECT
	ROUND(AVG(Total_Runs * 1.0 / Innings_Played), 2) AS Overall_Avg_Runs
FROM player_runs
WHERE Innings_Played > 0
),
player_wickets AS (
SELECT
	b.Bowler AS Player_Id,
	COUNT(w.Player_Out) AS Total_Wickets
FROM Ball_by_Ball b
JOIN Wicket_Taken w ON b.Match_Id = w.Match_Id
AND b.Over_Id = w.Over_Id
AND b.Ball_Id = w.Ball_Id
AND b.Innings_No = w.Innings_No
GROUP BY b.Bowler
),
overall_avg_wickets AS (
SELECT
	ROUND(AVG(Total_Wickets), 2) AS Overall_Wickets
FROM player_wickets
)
SELECT
	p.Player_Name,
	r.Avg_Runs,
	w.Total_Wickets
FROM player_avg_runs r
JOIN overall_avg_runs oar ON 1=1
JOIN player_wickets w ON r.Player_Id = w.Player_Id
JOIN overall_avg_wickets oaw ON 1=1
JOIN Player p ON p.Player_Id = r.Player_Id
WHERE r.Avg_Runs > oar.Overall_Avg_Runs
AND w.Total_Wickets > oaw.Overall_Wickets;


--rcb_record table that shows the wins and losses of RCB in an individual venue.
SELECT 
   		v.Venue_Name,
SUM(CASE WHEN m.Match_Winner = 2 THEN 1 ELSE 0 
END) AS Wins,
SUM(CASE WHEN (m.Match_Winner IS NOT NULL AND m.Match_Winner != 2 AND (m.Team_1 = 2 OR m.Team_2 = 2)) 
        		THEN 1 
           		ELSE 0 
        		END) AS Losses	
FROM Matches m
JOIN Venue v ON m.Venue_Id = v.Venue_Id
WHERE 
    	(m.Team_1 = 2 OR m.Team_2 = 2)  -- RCB participated
GROUP BY v.Venue_Name
ORDER BY wins desc, losses asc;
WITH rcb_record AS (
    	SELECT
        v.Venue_Name,
        COUNT(*) AS Total_Matches,
        SUM(CASE WHEN m.Match_Winner = t.Team_Id THEN 1 ELSE 0 END) AS Wins,
        SUM(
            CASE 
                WHEN m.Match_Winner != t.Team_Id 
                     AND (m.Team_1 = t.Team_Id OR m.Team_2 = t.Team_Id) 
                THEN 1 
                ELSE 0 
            END
        ) AS Loses
   	FROM matches m
    	INNER JOIN team t 
        ON (t.Team_Name = 'Royal Challengers Bangalore')
    	INNER JOIN venue v 
        ON m.Venue_Id = v.Venue_Id
   	WHERE (m.Team_1 = t.Team_Id OR m.Team_2 = t.Team_Id)
   	GROUP BY v.Venue_Name
)

SELECT 
    		Venue_Name,
    		Total_Matches,
   		Wins,
    		Loses,
    		(Total_Matches - (Wins + Loses)) AS NR
FROM rcb_record;


--impact of bowling style on wickets taken
SELECT 
bs.Bowling_skill, 
COUNT(wt.Player_Out) AS Wickets_Taken
FROM player p
INNER JOIN bowling_style bs 
ON p.Bowling_skill = bs.Bowling_Id
INNER JOIN ball_by_ball bb 
ON p.Player_Id = bb.Bowler
INNER JOIN wicket_taken wt 
    	ON bb.Match_Id = wt.Match_Id 
 	AND bb.Over_Id = wt.Over_Id 
   	AND bb.Ball_Id = wt.Ball_Id
WHERE wt.Kind_Out <> 3 -- Removing Run Outs
GROUP BY bs.Bowling_skill
ORDER BY Wickets_Taken DESC;


--11.	Write the SQL query to provide a status of whether the performance of the team is better than the previous year's performance on the basis of the number of runs scored by the team in the season and the number of wickets taken.
WITH team_runs AS (
SELECT 
m.season_id,
           b.team_batting     AS Team_Id,
           Sum(b.runs_scored) AS Total_Runs
      	FROM   ball_by_ball b
      JOIN matches m
      ON b.match_id = m.match_id
      GROUP  BY m.season_id, b.team_batting
),
     team_wickets AS (
SELECT 
m.season_id,
           b.team_bowling      AS Team_Id,
           Count(w.player_out) AS Total_Wickets
     FROM   ball_by_ball b
     JOIN matches m
     ON b.match_id = m.match_id
     JOIN wicket_taken w
     ON b.match_id = w.match_id
     AND b.over_id = w.over_id
     AND b.ball_id = w.ball_id
     AND b.innings_no = w.innings_no
     GROUP  BY m.season_id, b.team_bowling
),
     combined AS (
SELECT 
r.season_id,
           r.team_id,
           r.total_runs,
           w.total_wickets
FROM   team_runs r
JOIN team_wickets w
 ON r.season_id = w.season_id
AND r.team_id = w.team_id),
with_previous AS (
SELECT 
c.*,
           s.season_year,
           Lag(c.total_runs) OVER (partition BY c.team_id
           ORDER BY s.season_year) AS Prev_Total_Runs,
           Lag(c.total_wickets) OVER (partition BY c.team_id
         ORDER BY s.season_year) AS Prev_Total_Wickets
FROM   combined c
JOIN season s
ON c.season_id = s.season_id)
SELECT t.team_name,
       wp.season_year,
       wp.total_runs,
       wp.total_wickets,
       wp.prev_total_runs,
       wp.prev_total_wickets,
       CASE
         WHEN wp.total_runs > wp.prev_total_runs
              AND wp.total_wickets > wp.prev_total_wickets THEN 'Improved'
         WHEN wp.total_runs < wp.prev_total_runs
              AND wp.total_wickets < wp.prev_total_wickets THEN 'Declined'
         ELSE 'Same'
       END AS Performance_Status
FROM   with_previous wp
       JOIN team t
         ON wp.team_id = t.team_id
WHERE  wp.prev_total_runs IS NOT NULL
       AND wp.prev_total_wickets IS NOT NULL
ORDER  BY t.team_name,
          wp.season_year; 



--Using SQL, write a query to find out the average wickets taken by each bowler in each venue. Also, rank the gender according to the average value.
WITH Bowler_Avg_Wickets AS (
    SELECT
        p.Player_Id,
        p.Player_Name,
        v.Venue_Name,
        COUNT(wt.Player_Out) / COUNT(DISTINCT m.Match_Id) AS Avg_Wickets
    FROM ball_by_ball AS bb
    JOIN wicket_taken AS wt
     ON bb.Match_Id = wt.Match_Id
     AND bb.Innings_No = wt.Innings_No
     AND bb.Over_Id = wt.Over_Id
     AND bb.Ball_Id = wt.Ball_Id
     JOIN player AS p
     ON bb.Bowler = p.Player_Id
     JOIN matches AS m
     ON bb.Match_Id = m.Match_Id
     JOIN venue AS v
     ON m.Venue_Id = v.Venue_Id
     GROUP BY 
        p.Player_Id,
        p.Player_Name,
        v.Venue_Name
)

SELECT
    Player_Id,
    Player_Name,
    Venue_Name,
    Avg_Wickets,
    ROW_NUMBER() OVER (ORDER BY Avg_Wickets DESC) AS Wicket_Rank
FROM Bowler_Avg_Wickets
ORDER BY Wicket_Rank;


--14.	Which of the given players have consistently performed well in past seasons
use ipl;
WITH Player_Season_Performance AS (
    SELECT 
        p.Player_Name, 
        s.Season_Year, 
        SUM(bbb.Runs_Scored) AS Total_Runs, 
        COUNT(wt.Player_Out) AS Total_Wickets,
        COUNT(DISTINCT m.Match_Id) AS Matches_Played
    FROM Player p
    INNER JOIN Ball_by_Ball bbb ON p.Player_Id = bbb.Striker
    LEFT JOIN Wicket_Taken wt ON bbb.Match_Id = wt.Match_Id 
                              AND bbb.Over_Id = wt.Over_Id 
                              AND bbb.Ball_Id = wt.Ball_Id 
                              AND bbb.Innings_No = wt.Innings_No
    INNER JOIN Matches m ON bbb.Match_Id = m.Match_Id
    INNER JOIN Season s ON m.Season_Id = s.Season_Id
    WHERE p.Player_Id = bbb.Bowler OR p.Player_Id = bbb.Striker
    GROUP BY p.Player_Name, s.Season_Year
)
SELECT 
    Player_Name, 
    AVG(Total_Runs) AS Avg_Runs_Per_Season, 
    AVG(Total_Wickets) AS Avg_Wickets_Per_Season, 
    COUNT(Season_Year) AS Seasons_Played
FROM Player_Season_Performance
GROUP BY Player_Name
HAVING Seasons_Played > 3
ORDER BY Avg_Runs_Per_Season DESC, Avg_Wickets_Per_Season DESC
LIMIT 10;


--Are there players whose performance is more suited to specific venues or conditions? 
SELECT 
p.Player_Name,
v.Venue_Name,
SUM(bbb.Runs_Scored) AS Total_Runs,
COUNT(*) AS Balls_Faced,
    ROUND(SUM(bbb.Runs_Scored) * 1.0 / COUNT(*), 2) AS Strike_Rate
FROM ball_by_ball bbb
JOIN matches m 
    ON bbb.Match_Id = m.Match_Id
JOIN venue v 
    ON m.Venue_Id = v.Venue_Id
JOIN player p 
    ON bbb.Striker = p.Player_Id
GROUP BY p.Player_Name, v.Venue_Name
HAVING COUNT(*) >= 10  -- Filter to ensure minimum balls faced
ORDER BY p.Player_Name, Total_Runs DESC;


--SUBJECTIVE QUESTIONS
--How does the toss decision affect the result of the match? (which visualizations could be used to present your answer better) And is the impact limited to only specific venues
SELECT 
    v.Venue_Name,
    td.Toss_Name AS Toss_Decision,
    COUNT(*) AS Total_Matches,
    SUM(CASE WHEN m.Toss_winner = m.Match_winner THEN 1 ELSE 0 END) AS Wins_After_Toss,
    ROUND(
        SUM(CASE WHEN m.Toss_winner = m.Match_winner THEN 1 ELSE 0 END) * 100.0 / COUNT(*),
        2
    ) AS Win_Percentage
FROM matches m
JOIN toss_decision td ON m.Toss_Decide = td.Toss_Id
JOIN venue v ON m.Venue_Id = v.Venue_Id
GROUP BY v.Venue_Name, td.Toss_Name
ORDER BY v.Venue_Name, Win_Percentage DESC;

--Suggest some of the players who would be best fit for the team.
--FOR BATTING
SELECT 
    p.Player_Name,
    COUNT(*) AS Balls_Faced,
    SUM(bbb.Runs_Scored) AS Total_Runs,
    ROUND(SUM(bbb.Runs_Scored) * 100.0 / COUNT(*), 2) AS Strike_Rate
FROM ball_by_ball bbb
JOIN matches m ON bbb.Match_Id = m.Match_Id
JOIN season s ON m.Season_Id = s.Season_Id
JOIN player p ON bbb.Striker = p.Player_Id
WHERE s.Season_Year >= (SELECT MAX(Season_Year) - 3 FROM season)
GROUP BY p.Player_Name
HAVING COUNT(*) >= 50  -- minimum balls faced
ORDER BY Strike_Rate DESC, Total_Runs DESC
LIMIT 10;

--FOR BOWLING
SELECT 
    p.Player_Name,
    COUNT(*) AS Balls_Bowled,
    COUNT(wt.Player_Out) AS Wickets,
    ROUND(COUNT(wt.Player_Out) * 1.0 / COUNT(*), 2) AS Wicket_Per_Ball
FROM ball_by_ball bbb
JOIN matches m ON bbb.Match_Id = m.Match_Id
JOIN season s ON m.Season_Id = s.Season_Id
JOIN player p ON bbb.Bowler = p.Player_Id
LEFT JOIN wicket_taken wt 
    ON bbb.Match_Id = wt.Match_Id
    AND bbb.Over_Id = wt.Over_Id
    AND bbb.Ball_Id = wt.Ball_Id
    AND bbb.Innings_No = wt.Innings_No
WHERE s.Season_Year >= (SELECT MAX(Season_Year) - 3 FROM season)
GROUP BY p.Player_Name
HAVING COUNT(*) >= 30  -- min balls/overs
ORDER BY Wickets DESC, Wicket_Per_Ball DESC
LIMIT 10;


--Which players offer versatility in their skills and can contribute effectively with both bat and ball
WITH Top_Batsmen AS (
    SELECT Striker AS Player_Id, p.Player_Name, SUM(Runs_Scored) AS Total_Runs
    FROM ball_by_ball 
    JOIN player p ON Striker = p.Player_Id
    GROUP BY Striker, p.Player_Name
    ORDER BY Total_Runs DESC
    LIMIT 100
),
Top_Bowlers AS (
    SELECT b.Bowler AS Player_Id, p.Player_Name, COUNT(w.Player_Out) AS Total_Wickets
    FROM wicket_taken w
    JOIN ball_by_ball b USING (Match_Id, Over_Id, Ball_Id)
    JOIN player p ON b.Bowler = p.Player_Id
    GROUP BY b.Bowler, p.Player_Name
    ORDER BY Total_Wickets DESC
    LIMIT 100
)
SELECT b.Player_Id, b.Player_Name, b.Total_Runs, bo.Total_Wickets
FROM Top_Batsmen b
JOIN Top_Bowlers bo USING (Player_Id)
ORDER BY b.Total_Runs DESC, bo.Total_Wickets DESC
LIMIT 10;


--Are there players whose presence positively influences the morale and performance of the team
SELECT
    p.Player_Name,
    COUNT(pm.Match_Id) AS Matches_Played,
    COUNT(CASE WHEN m.Win_Type = t.Team_Id THEN 1 END) AS Matches_Won
FROM
    player_match pm
    JOIN player p ON pm.Player_Id = p.Player_Id
    JOIN team t ON pm.Team_Id = t.Team_Id
    JOIN matches m ON pm.Match_Id = m.Match_Id
WHERE
    t.Team_Name = 'Royal Challengers Bangalore'
GROUP BY
    p.Player_Name
ORDER BY
    Matches_Won DESC
LIMIT 10;

--Top 5 Run Scorers for RCB(team_id=2)
SELECT p.Player_Name, SUM(b.Runs_Scored) AS Total_Runs
FROM ball_by_ball b
JOIN player p ON b.Striker = p.Player_Id
JOIN team t ON b.Team_Batting = t.Team_Id
WHERE t.Team_Id = '2'
GROUP BY p.Player_Name
ORDER BY Total_Runs DESC
LIMIT 5;


--RCB Overall Win Percentage
SELECT 
    (SUM(CASE WHEN Match_Winner = '2' THEN 1 ELSE 0 END) * 100.0) / COUNT(*) AS Win_Percentage
FROM matches;

--RCB bowling performance in Death Overs:
Select p.Player_name, 
COUNT(*) AS Balls_Bowled, 
(SUM(b.Runs_Scored) / (COUNT(*) / 6)) AS Economy_Rate,
COUNT(w.Match_Id) AS Wickets_Taken
FROM ball_by_ball b
JOIN team t ON b.Team_Batting != t.Team_Id
LEFT JOIN wicket_taken w ON b.Match_Id = w.Match_Id 
                          AND b.Ball_Id = w.Ball_Id
                          AND b.Over_Id BETWEEN 16 AND 20
WHERE b.Over_Id BETWEEN 16 AND 20
AND t.Team_Id='2'
GROUP BY b.Bowler
ORDER BY Economy_Rate DESC;


--
