-- PART I: SCHOOL ANALYSIS
USE maven_advanced_sql;
-- 1. View the schools and school details tables

SELECT s.schoolID, s.yearID, sd.name_full, sd.city, sd.state, sd.country
FROM schools s
LEFT JOIN school_details sd
ON s.schoolID = sd.schoolID
ORDER BY s.yearID ASC;

-- 2. In each decade, how many schools were there that produced players?

SELECT FLOOR(yearID/10)*10 as decade, COUNT(DISTINCT schoolID) as school_total
FROM schools
GROUP BY decade
ORDER BY decade ASC;

-- 3. What are the names of the top 5 schools that produced the most players?

SELECT sd.name_full, COUNT(DISTINCT s.playerID) as players_count
FROM schools s
LEFT JOIN school_details sd
ON s.schoolID = sd.schoolID
GROUP BY sd.name_full
ORDER BY players_count DESC
LIMIT 5;

-- 4. For each decade, what were the names of the top 3 schools that produced the most players?

WITH cte_1 AS (
SELECT FLOOR(yearID/10)*10 as decade, schoolID, COUNT(DISTINCT playerID) as total_pl
FROM schools
GROUP BY schoolID, decade
ORDER BY total_pl DESC),
final_cte AS (
SELECT decade, schoolID, total_pl,
ROW_NUMBER() OVER(PARTITION BY decade ORDER BY total_pl DESC) AS row_num
FROM cte_1)
SELECT decade, name_full, total_pl
FROM final_cte
LEFT JOIN school_details
ON school_details.schoolID = final_cte.schoolID
WHERE row_num <=3;

-- PART II: SALARY ANALYSIS
-- 1. View the salaries table

SELECT * 
FROM salaries;

-- 2. Return the top 20% of teams in terms of average annual spending

WITH salar AS (
    SELECT teamID, yearID,
           AVG(salary) AS med_salary
    FROM salaries
    GROUP BY yearID, teamID
),
per_20 AS ( 
    SELECT teamID, yearID, med_salary,
           NTILE(5) OVER (ORDER BY med_salary DESC) AS salary_rank
    FROM salar
)
SELECT teamID, yearID, med_salary
FROM per_20
WHERE salary_rank = 1;

-- 3. For each team, show the cumulative sum of spending over the years

WITH total AS (
SELECT yearID, teamID, SUM(salary) as total_sum
FROM salaries
GROUP by yearID, teamID)

SELECT yearID, teamID, 
SUM(total_sum) OVER(PARTITION BY teamID ORDER BY yearID) as cumulative_sum
FROM total;

-- 4. Return the first year that each team's cumulative spending surpassed 1 billion

WITH total AS (
SELECT yearID, teamID, SUM(salary) as total_sum
FROM salaries
GROUP by yearID, teamID),
yearly AS (
SELECT yearID, teamID, 
SUM(total_sum) OVER(PARTITION BY teamID ORDER BY yearID) as cumulative_sum
FROM total),
over_bil AS (
SELECT yearID, teamID, cumulative_sum, 
ROW_NUMBER() OVER(PARTITION BY teamID ORDER BY cumulative_sum ASC) AS row_num
FROM yearly
WHERE cumulative_sum > 1000000000)

SELECT yearID, teamID, cumulative_sum
FROM over_bil
WHERE row_num = 1
ORDER BY yearID ASC;

-- PART III: PLAYER CAREER ANALYSIS
-- 1. View the players table and find the number of players in the table

SELECT COUNT(DISTINCT playerID) as num_player
FROM players;

-- 2. For each player, calculate their age at their first game, their last game, and their career length (all in years). 
-- Sort from longest career to shortest career.

WITH start_cte AS (SELECT playerID, nameGiven, 
STR_TO_DATE(CONCAT(birthYear, '-', birthMonth, '-', birthDay), '%Y-%m-%d') AS birth_date,
debut, finalGame
FROM players)
SELECT *, TIMESTAMPDIFF(YEAR, birth_date, debut) AS first_game_age,
TIMESTAMPDIFF(YEAR, birth_date, finalGame) AS last_game_age,
(TIMESTAMPDIFF(YEAR, birth_date, finalGame) - TIMESTAMPDIFF(YEAR, birth_date, debut)) as career_len
FROM start_cte
ORDER BY career_len DESC;

-- 3. What team did each player play on for their starting and ending years?

SELECT p.playerID, s.yearID as starting_year, s.teamID as starting_team,
s2.yearID as end_year, s2.teamID as end_team
FROM players p
JOIN salaries s
ON p.playerID = s.playerID AND YEAR(p.debut) = s.yearID
JOIN salaries s2
ON p.playerID = s2.playerID AND YEAR(p.finalGame) = s2.yearID;

-- 4. How many players started and ended on the same team and also played for over a decade?
 
 WITH start_cte AS (
SELECT p.playerID, s.yearID as starting_year, s.teamID as starting_team,
s2.yearID as end_year, s2.teamID as end_team
FROM players p
JOIN salaries s
ON p.playerID = s.playerID AND YEAR(p.debut) = s.yearID
JOIN salaries s2
ON p.playerID = s2.playerID AND YEAR(p.finalGame) = s2.yearID)

SELECT COUNT(playerID) AS resulting_players
FROM start_cte
WHERE starting_team = end_team AND end_year-starting_year > 10;

-- PART IV: PLAYER COMPARISON ANALYSIS
-- 1. View the players table

SELECT * 
FROM players;

-- 2. Which players have the same birthday?

SELECT 
    STR_TO_DATE(CONCAT(birthYear, '-', birthMonth, '-', birthDay), '%Y-%m-%d') AS birth_date,
    GROUP_CONCAT(nameGiven ORDER BY nameGiven SEPARATOR ', ') AS players
FROM 
    players
GROUP BY 
    birth_date
HAVING COUNT(*) > 1 AND birth_date IS NOT NULL
ORDER BY 
    birth_date;
        
-- 3. Create a summary table that shows for each team, what percent of players bat right, left and both

WITH start_cte AS (SELECT teamID,
SUM(CASE WHEN bats = 'L' THEN 1 ELSE 0 END) AS lefties,
SUM(CASE WHEN bats = 'R' THEN 1 ELSE 0 END) AS righties,
SUM(CASE WHEN bats = 'B' THEN 1 ELSE 0 END) AS bothies
FROM players p
JOIN salaries s 
ON s.playerID= p.playerID
GROUP BY teamID),
total_cte AS (
SELECT teamID, SUM(lefties+righties+bothies) AS total_perc
FROM start_cte
GROUP BY teamID)

SELECT total_cte.teamID, 
CONCAT(ROUND(lefties/total_perc*100, 2),'%') AS left_perc,
CONCAT(ROUND(righties/total_perc*100, 2),'%') AS right_perc,
CONCAT(ROUND(bothies/total_perc*100, 2),'%') AS both_perc
FROM total_cte
JOIN start_cte
ON total_cte.teamID = start_cte.teamID;

-- 4. How have average height and weight at debut game changed over the years, and what's the decade-over-decade difference?

WITH start_cte AS (
SELECT FLOOR(YEAR(debut)/10)*10 AS decade, AVG(height) AS avg_h, AVG(weight) as avg_w
FROM players
GROUP BY decade)

SELECT decade, avg_h -LAG(avg_h) OVER(ORDER BY decade) as h_dif,
avg_w - LAG(avg_w) OVER(ORDER BY decade) as w_dif
FROM start_cte
WHERE decade IS NOT NULL;