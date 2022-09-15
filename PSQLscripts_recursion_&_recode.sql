--1.1.	���� PostgreSQL
DROP TABLE IF EXISTS t_dicService;
CREATE TABLE t_dicService (
  sCode varchar(256),
  sParentCode varchar(256) NULL,
  sDescription varchar(256)
);
--1.2.	������ ��������:
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

--�����:
--scode                                     |schaincode                                            |sdescription                                   
---------------                             +----------------------------------               +-----------------------------------------------
--!DAILY_SCHED                              |!!BASE|!DAILY_SCHED                              |����� "����������� ����������� ����������"     
--!KERNEL_CCMIS                             |!!BASE|!KERNEL_CCMIS                             |����� "��������� ���������� ����������� �� MIS"
--!RUN                                      |!!RUN|!RUN                                       |RUN                                            
--ACCIDENT                                  |!!BASE|!MON|ACCIDENT                             |���������� �����������                         
--�			�				�
--.CSV ���� �������� ���� �������� ������ (154 ������) ����������� (cte_202206241414.csv)

--2. UTF8 / WIN1251 fight
DROP TABLE IF EXISTS name_table;
CREATE TABLE name_table (
  summary varchar(255),
  id numeric(38)
);

--INSERT INTO name_table (summary,id) VALUES
--	 ('�������+ ������ ��������� �� ���������� �� ������ ��',324422),
--	 ('������������',324424),
--	 ('�������� �������� ��� ������+',324425),
--	 ('���',326505),
--	 ('���� ���������� ��� ',326506),
--	 ('��� 30.09.2016',327409),
--	 ('���������� ������������� ���',327410),
--	 ('���� ������� ���',327411),
--	 ('����������� ������ ��� � ������ �������',328974),
--	 ('������ ��������  � ������ ��������    � ������ ����  �� ������  � ������ ������� ',328989);
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
--   ���������� �����
	RETURN convert_from(win1251Bytes, 'WIN1251');
  END;
  $$;

--��������: 
--������� ������ � ������� ��������� �������� �� �� win1251.
INSERT INTO name_table (summary, id) VALUES
	 ('This is utf8 symbols: >>>?<<<', 100500);
--�������� ��������� ���������� ������� convert_to:
--
--	������!
--
--������� ������� ����� ������� ������� summary:
--
--	������ ������� ��������������!

--������ ������ ����������� �������� ������ � ������������ �������� ������� varchar(255) �� UTF-8 � Win1251, ������ �������, ��� ����������� � Win1251.
DELETE FROM name_table 
WHERE id = 100500;

UPDATE name_table AS nt
    SET summary = utf8ToWin1251(summary);

--��� �������������, �������� ����� �������������� ����������� ������� UTF-8 � Win-1251, ����� ������ �����, ��� �� �������, ����� ���� ��������� ��� ����������� (������ � ���-���� ��������� �����������������, � ������� �� ���� ��������� ��� ��������� ����������� ������� ��� � Ascii �� 128-�� �������).
