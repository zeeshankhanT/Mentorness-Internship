
use game_analysis;

-- Problem Statement - Game Analysis dataset
-- 1) Players play a game divided into 3-levels (L0,L1 and L2)
-- 2) Each level has 3 difficulty levels (Low,Medium,High)
-- 3) At each level,players have to kill the opponents using guns/physical fight
-- 4) Each level has multiple stages at each difficulty level.
-- 5) A player can only play L1 using its system generated L1_code.
-- 6) Only players who have played Level1 can possibly play Level2 
--    using its system generated L2_code.
-- 7) By default a player can play L0.
-- 8) Each player can login to the game using a Dev_ID.
-- 9) Players can earn extra lives at each stage in a level.

alter table player_details modify L1_Status varchar(30);
alter table player_details modify L2_Status varchar(30);
alter table player_details modify P_ID int primary key;
alter table player_details drop myunknowncolumn;

alter table level_details2 drop myunknowncolumn;
alter table level_details2 change timestamp start_datetime datetime;
alter table level_details2 modify Dev_Id varchar(10);
alter table level_details2 modify Difficulty varchar(15);
alter table level_details2 add primary key(P_ID,Dev_id,start_datetime);

-- pd (P_ID,PName,L1_status,L2_Status,L1_code,L2_Code)
-- ld (P_ID,Dev_ID,start_time,stages_crossed,level,difficulty,kill_count,
-- headshots_count,score,lives_earned)


-- Q1) Extract P_ID,Dev_ID,PName and Difficulty_level of all players 
-- at level 0
SELECT p.P_ID, ld.Dev_ID, p.PName, ld.Difficulty as Difficulty_level, Level
FROM player_details p
JOIN level_details2 ld ON p.P_ID = ld.P_ID
WHERE ld.Level = 0;

-- Q2) Find Level1_code wise Avg_Kill_Count where lives_earned is 2 and atleast
--    3 stages are crossed
SELECT pd.L1_Code, AVG(ld.Kill_Count) as Average_Kill_Count, ld.Lives_Earned, ld.Stages_crossed
FROM player_details pd
JOIN level_details2 ld ON pd.P_ID = ld.P_ID
WHERE ld.Lives_Earned = 2 AND ld.Stages_crossed >= 3
GROUP BY pd.L1_Code, ld.Lives_Earned, ld.Stages_crossed;

-- Q3) Find the total number of stages crossed at each diffuculty level
-- where for Level2 with players use zm_series devices. Arrange the result
-- in decsreasing order of total number of stages crossed.
SELECT ld.Difficulty, SUM(ld.Stages_crossed) as Total_Stages_Crossed, Level, ld.Dev_ID
FROM level_details2 ld
JOIN player_details pd ON ld.P_ID = pd.P_ID
WHERE ld.Level = 2 AND ld.Dev_ID LIKE 'zm_%'
GROUP BY ld.Difficulty, ld.Dev_ID
ORDER BY Total_Stages_Crossed DESC;

-- Q4) Extract P_ID and the total number of unique dates for those players 
-- who have played games on multiple days.
SELECT P_ID, COUNT(DISTINCT DATE_FORMAT(start_datetime, '%y-%m-%d')) as Total_Unique_Dates
FROM level_details2
GROUP BY P_ID
HAVING COUNT(DISTINCT DATE_FORMAT(start_datetime, '%y-%m-%d')) > 1;

-- Q5) Find P_ID and level wise sum of kill_counts where kill_count
-- is greater than avg kill count for the Medium difficulty.
SELECT P_ID, Level, SUM(Kill_Count) as Total_Kill_Count
FROM level_details2 
WHERE Kill_Count > (
    SELECT AVG(Kill_Count)
    FROM level_details2
    WHERE Difficulty = 'Medium'
)
GROUP BY P_ID, Level;

-- Q6)  Find Level and its corresponding Level code wise sum of lives earned 
-- excluding level 0. Arrange in asecending order of level.
SELECT ld.Level, pd.L2_Code, SUM(ld.Lives_Earned) as Total_Lives_Earned
FROM level_details2 ld
JOIN player_details pd ON ld.P_ID = pd.P_ID
WHERE ld.Level > 0
GROUP BY ld.Level, pd.L2_Code
ORDER BY ld.Level ASC;

-- Q7) Find Top 3 score based on each dev_id and Rank them in increasing order
-- using Row_Number. Display difficulty as well. 
SELECT subquery.Dev_ID, subquery.Difficulty, subquery.Score, subquery.Rn
FROM (
    SELECT ld.Dev_ID, ld.Difficulty, ld.Score,
        ROW_NUMBER() OVER (PARTITION BY ld.Dev_ID ORDER BY ld.Score) as Rn
    FROM level_details2 ld) AS subquery
WHERE Rn <= 3;

-- Q8) Find first_login datetime for each device id
SELECT Dev_ID, MIN(start_datetime)as first_login
FROM level_details2
GROUP BY Dev_ID;

-- Q9) Find Top 5 score based on each difficulty level and Rank them in 
-- increasing order using Rank. Display dev_id as well.
SELECT subquery.Dev_ID, subquery.Difficulty, subquery.Score, subquery.Rn
FROM (
    SELECT ld.Dev_ID, ld.Difficulty, ld.Score,
        RANK() OVER (PARTITION BY ld.Difficulty ORDER BY ld.Score ASC) as Rn
    FROM level_details2 ld) AS subquery
WHERE Rn <= 5;

-- Q10) Find the device ID that is first logged in(based on start_datetime) 
-- for each player(p_id). Output should contain player id, device id and 
-- first login datetime.
SELECT P_ID, Dev_ID, MIN(start_datetime)as first_login
FROM level_details2
GROUP BY P_ID, Dev_ID;

-- Q11) For each player and date, how many kill_count played so far by the player. That is, the total number of games played -- by the player until that date.
-- a) window function
SELECT P_ID, DATE_FORMAT(start_datetime, '%y-%m-%d') as Date, Kill_Count,SUM(Kill_Count) 
OVER (PARTITION BY P_ID, DATE_FORMAT(start_datetime, '%y-%m-%d') ORDER BY start_datetime) as Total_Played_Kills_So_Far
FROM level_details2
ORDER BY P_ID, start_datetime;

-- b) without window function
SELECT P_ID, DATE_FORMAT(start_datetime, '%y-%m-%d')as Date, Kill_Count, SUM(Kill_Count) as Total_Played_Kills_So_Far
FROM level_details2
GROUP BY P_ID, start_datetime, Kill_Count
ORDER BY P_ID, start_datetime;

-- Q12) Find the cumulative sum of an stages crossed over a start_datetime 
-- for each player id but exclude the most recent start_datetime
SELECT ld.P_ID, ld.start_datetime, ld.Stages_Crossed,
    ( SELECT SUM(Stages_Crossed) 
        FROM level_details2 
        WHERE P_ID = ld.P_ID AND start_datetime < ld.start_datetime
    ) as Cumulative_Stages_Crossed
FROM level_details2 ld
WHERE NOT EXISTS (
    SELECT 1 FROM level_details2 ld2 
    WHERE ld.P_ID = ld2.P_ID AND ld.start_datetime < ld2.start_datetime
)
ORDER BY ld.P_ID, ld.start_datetime;

-- Q13) Extract top 3 highest sum of score for each device id and the corresponding player_id
SELECT Dev_ID, P_ID, SUM(Score) as Total_Score
FROM level_details2
GROUP BY Dev_ID, P_ID
ORDER BY Dev_ID, Total_Score DESC
LIMIT 3;

-- Q14) Find players who scored more than 50% of the avg score scored by sum of 
-- scores for each player_id
SELECT pd.P_ID, pd.PName, AVG(ld2.Score) as Average_Score
FROM player_details pd
JOIN level_details2 ld2 ON pd.P_ID = ld2.P_ID
JOIN ( SELECT P_ID, AVG(Score) as Player_Avg_Score
    FROM level_details2
    GROUP BY P_ID
) avg_scores ON pd.P_ID = avg_scores.P_ID
WHERE ld2.Score > 0.5 * avg_scores.Player_Avg_Score
GROUP BY pd.P_ID, pd.PName

-- Q15) Create a stored procedure to find top n headshots_count based on each dev_id and Rank them in increasing order
-- using Row_Number. Display difficulty as well.
DELIMITER //
CREATE PROCEDURE FindTopHeadshotsCount(IN n INT)
BEGIN CREATE TEMPORARY TABLE temp_table AS
    SELECT ld.Dev_ID, ld.headshots_count, ld.difficulty,
        ROW_NUMBER() OVER (PARTITION BY ld.Dev_ID ORDER BY ld.headshots_count) as rn
    FROM level_details2 ld
    WHERE ld.headshots_count IS NOT NULL;
    SELECT Dev_ID, headshots_count, difficulty
    FROM temp_table
    WHERE rn <= n;
    DROP TEMPORARY TABLE IF EXISTS temp_table;
END //
DELIMITER ;
CALL FindTopHeadshotsCount(3);
