--1.1.	СУБД PostgreSQL
DROP TABLE IF EXISTS t_dicService;
CREATE TABLE t_dicService (
  sCode varchar(256),
  sParentCode varchar(256) NULL,
  sDescription varchar(256)
);
--1.2.	Скрипт рекурсии:
WITH RECURSIVE cte (sCode, sChainCode, sDescription, sParentCode) 
  as (SELECT sCode, sCode::character varying, sDescription, sParentCode
    FROM t_dicService
    WHERE sParentCode is NULL
  union all
    SELECT t.sCode, CONCAT(sChainCode, '|', t.sCode), t.sDescription, t.sParentCode
    FROM t_dicService t
    JOIN cte ON cte.sCode = t.sParentCode
    )
SELECT sCode, sChainCode, sDescription
FROM cte
WHERE sCode NOT IN (SELECT st.sParentCode FROM t_dicService st
						WHERE st.sParentCode is not NULL)
ORDER BY sCode;

--ВЫВОД:
--scode                                     |schaincode                                            |sdescription                                   
---------------                             +----------------------------------               +-----------------------------------------------
--!DAILY_SCHED                              |!!BASE|!DAILY_SCHED                              |Пакет "Оркестровка оперативной отчетности"     
--!KERNEL_CCMIS                             |!!BASE|!KERNEL_CCMIS                             |Пакет "Платформа реализации функционала ЦК MIS"
--!RUN                                      |!!RUN|!RUN                                       |RUN                                            
--ACCIDENT                                  |!!BASE|!MON|ACCIDENT                             |Управление инцидентами                         
--…			…				…
--.CSV файл экспорта всех выходных данных (154 строки) прилагается (cte_202206241414.csv)

--2. UTF8 / WIN1251 fight
DROP TABLE IF EXISTS name_table;
CREATE TABLE name_table (
  summary varchar(255),
  id numeric(38)
);

--INSERT INTO name_table (summary,id) VALUES
--	 ('Средний+ замена источника по эквайрингу на данные РБ',324422),
--	 ('Согласование',324424),
--	 ('заменить источник для Среднй+',324425),
--	 ('НСИ',326505),
--	 ('СТАС Глобальная НСИ ',326506),
--	 ('НУК 30.09.2016',327409),
--	 ('Мониторинг использования НУК',327410),
--	 ('Узел расчета НУК',327411),
--	 ('Отображение статей ОПУ в статьи баланса',328974),
--	 ('Расчет периодов  с начала квартала    с начала года  на основе  с начала периода ',328989);
--...
	
DROP FUNCTION IF EXISTS utf8ToWin1251;
CREATE OR REPLACE FUNCTION utf8ToWin1251(input TEXT) RETURNS TEXT language plpgsql AS $$
  DECLARE
    inputAsArray TEXT[] := regexp_split_to_array(input, '');
    currentAsciiCode INTEGER;
    resultString TEXT;
    win1251Bytes BYTEA;
  BEGIN
    FOR i IN 1..LENGTH(input) LOOP
      currentAsciiCode := ascii(inputAsArray[i]);
      IF
        currentAsciiCode > x'7F'::INTEGER
        AND NOT (currentAsciiCode >= x'410'::INTEGER AND currentAsciiCode <= x'44F'::INTEGER)
      THEN
        RAISE NOTICE 'replaced_to_nothing % (%)', inputAsArray[i], currentAsciiCode;
        inputAsArray[i] := '';
      END IF;
    END LOOP;
    resultString := array_to_string(inputAsArray, '');
    win1251Bytes = convert_to(resultString, 'WIN1251');
--   возвращаем текст
	RETURN convert_from(win1251Bytes, 'WIN1251');
  END;
  $$;

--ПРОВЕРКА: 
--Добавим строку с заранее известным символом не из win1251.
INSERT INTO name_table (summary, id) VALUES
	 ('This is utf8 symbols: >>>?<<<', 100500);
--Проверим результат выполнения функции convert_to:
--
--	ОШИБКА!
--
--Обернем вызовом нашей функции столбец summary:
--
--	Данные успешно конвертируются!

--Теперь удалим добавленные тестовые данные и конвертируем значения столбца varchar(255) из UTF-8 в Win1251, удаляя символы, что отсутствуют в Win1251.
DELETE FROM name_table 
WHERE id = 100500;

UPDATE name_table AS nt
    SET summary = utf8ToWin1251(summary);

--При необходимости, возможно более детализировано сопоставить символы UTF-8 и Win-1251, чтобы редкие знаки, при их наличии, также были сохранены при конвертации (идущие в таб-лице кодировки непоследовательно, в отличие от букв кириллицы или полностью сохраняющих порядок как в Ascii до 128-го символа).
