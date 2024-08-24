SET search_path TO bookings;

--1. Выведите название самолетов, которые имеют менее 50 посадочных мест
EXPLAIN ANALYZE
SELECT model ,  count(s.*)
FROM aircrafts a 
	JOIN seats s ON a.aircraft_code = s.aircraft_code 
GROUP BY model
HAVING count(s.*) < 50


EXPLAIN ANALYZE
SELECT a.model 
FROM (
	SELECT aircraft_code
	FROM seats s 
	GROUP BY s.aircraft_code 
	HAVING count(s.seat_no) < 50 ) s1
	JOIN aircrafts a ON a.aircraft_code = s1.aircraft_code


--2. Выведите процентное изменение ежемесячной суммы бронирования билетов, округленной до сотых.

SELECT Месяц, round((sum_amount / LAG(sum_amount) OVER () - 1) * 100, 2) AS "Прирост суммы бронирования, %"
FROM (
	SELECT 
		EXTRACT (month FROM book_date) AS "Месяц", 
		sum(total_amount) AS sum_amount
	FROM bookings b 
	GROUP BY EXTRACT (month FROM book_date)
	ORDER BY Месяц) b1
	
	

--3. Выведите названия самолетов не имеющих бизнес - класс. Решение должно быть через функцию array_agg.
	
SELECT model 
FROM aircrafts a 
	JOIN seats s ON a.aircraft_code = s.aircraft_code 
GROUP BY a.aircraft_code
HAVING NOT (array_agg(fare_conditions) && '{"Business"}')

SELECT model
FROM aircrafts a 
	JOIN (
		SELECT aircraft_code
		FROM seats s 
		GROUP BY s.aircraft_code 
		HAVING NOT (array_agg(fare_conditions) && '{"Business"}')) s1 ON a.aircraft_code = s1.aircraft_code 


--4. Вывести накопительный итог количества мест в самолетах по каждому аэропорту на
--каждый день, учитывая только те самолеты, которые летали пустыми и только те дни, где
--из одного аэропорта таких самолетов вылетало более одного.
--В результате должны быть код аэропорта, дата, количество пустых мест в самолете и
--накопительный итог.


SELECT actual_departure::date, departure_airport, seat_number, 
	sum(seat_number) OVER (PARTITION BY actual_departure::date, departure_airport ORDER BY actual_departure)
FROM (
	SELECT 
		actual_departure, departure_airport, aircraft_code,
		count(*) OVER (PARTITION BY actual_departure::date, departure_airport) AS flight_count
	FROM flights f 
		JOIN (
			SELECT flight_id FROM flights
			EXCEPT
			SELECT flight_id FROM boarding_passes) f1 ON f.flight_id = f1.flight_id
	WHERE actual_departure IS NOT NULL ) s1
	JOIN (
		SELECT a.aircraft_code, count(s.seat_no) AS seat_number
		FROM aircrafts a 
			JOIN seats s ON a.aircraft_code = s.aircraft_code 
		GROUP BY a.aircraft_code ) a1 ON s1.aircraft_code = a1.aircraft_code
WHERE flight_count > 1


--5. Найдите процентное соотношение перелетов по маршрутам от общего количества перелетов.
--Выведите в результат названия аэропортов и процентное отношение.
--Решение должно быть через оконную функцию.	


SELECT
	a1.airport_name AS "Аэропорт вылета", 
	a2.airport_name AS "Аэропорт прилета", 
	round( count(f.flight_no) * 100 / sum(count(f.flight_no)) OVER (), 2) AS "Доля от общего количества, %"
FROM flights f 
	JOIN airports a1 ON f.departure_airport = a1.airport_code 
	JOIN airports a2 ON f.arrival_airport = a2.airport_code
GROUP BY a1.airport_name , a2.airport_name


--6. Выведите количество пассажиров по каждому коду сотового оператора, если учесть, что
--код оператора - это три символа после +7

 
SELECT op_code, count(op_code) 
FROM (
	SELECT substring( contact_data ->> 'phone' FROM 3 FOR 3) AS op_code
	FROM tickets t ) t1
GROUP BY op_code


--7. Классифицируйте финансовые обороты (сумма стоимости перелетов) по маршрутам:
--До 50 млн - low
--От 50 млн включительно до 150 млн - middle
--От 150 млн включительно - high
--Выведите в результат количество маршрутов в каждом полученном классе


SELECT class_sum, count(flight_no) 
FROM (
	SELECT flight_no , 
		CASE WHEN sum(amount) < 50000000 THEN 'low'
			WHEN sum(amount) >= 150000000 THEN 'high'
			ELSE 'middle'
		END class_sum
	FROM flights f JOIN ticket_flights tf ON f.flight_id = tf.flight_id 
	GROUP BY flight_no ) f1
GROUP BY class_sum 


--8. Вычислите медиану стоимости перелетов, медиану размера бронирования и отношение
--медианы бронирования к медиане стоимости перелетов, округленной до сотых

SELECT flight_mediane, book_mediane, round(book_mediane / flight_mediane, 2) AS relation
FROM (
	SELECT 
		(SELECT percentile_disc(0.5) WITHIN GROUP (ORDER BY amount) 
		FROM ticket_flights tf) AS  flight_mediane,
		(SELECT percentile_disc(0.5) WITHIN GROUP (ORDER BY total_amount) 
		FROM bookings b) AS book_mediane) s1
		

--9. Найдите значение минимальной стоимости полета 1 км для пассажиров. То есть нужно
--найти расстояние между аэропортами и с учетом стоимости перелетов получить искомый результат
	
CREATE EXTENSION CUBE;
CREATE EXTENSION earthdistance ;
SELECT min(min_amount / distance) 
FROM (
	SELECT 
		flight_no, 
		earth_distance(ll_to_earth (a1.latitude , a1.longitude),ll_to_earth (a2.latitude , a2.longitude))/1000 AS distance,
		min(amount) AS min_amount
	FROM flights f 
		JOIN airports a1 ON f.departure_airport = a1.airport_code 
		JOIN airports a2 ON f.arrival_airport = a2.airport_code 
		JOIN ticket_flights tf ON f.flight_id = tf.flight_id 
	GROUP BY flight_no, a1.latitude , a1.longitude, a2.latitude , a2.longitude) f1  
	
	
	
