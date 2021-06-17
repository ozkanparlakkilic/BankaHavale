CREATE DATABASE BankaDb
GO
USE BankaDb
GO
CREATE TABLE ABanka
(
   HesapNo INT,
   Bakiye MONEY,
)
GO
CREATE TABLE BBanka
(
   HesapNo INT,
   Bakiye MONEY,
)
GO
CREATE TABLE CBanka
(
   HesapNo INT,
   Bakiye MONEY,

)
INSERT ABanka VALUES(10,1000),
					(20,2500)
INSERT BBanka VALUES(30,2300),
					(40,760)
INSERT CBanka VALUES(50,4000),
					(60,800)
GO

ALTER PROC sp_HavaleYap
(
   @BankaKimden NVARCHAR(MAX),
   @BankaKime NVARCHAR(MAX),
   @GonderenHesapNo INT,
   @AlanHesapNo INT,
   @Tutar MONEY
)
AS
BEGIN TRAN Kontrol
	BEGIN
			-- De�i�kenler tan�mland� ve de�i�kene sorgu de�eri atmak i�in baz� veriler ge�ici olarak nvarchar a d�n��t�r�ld�
			DECLARE @GonderenBakiye INT,@AlanBakiye INT,@HesaptakiPara MONEY,
			@GonderenHesapNoString NVARCHAR(MAX),@AlanHesapNoString NVARCHAR(MAX),
			@HesaptakiParaString NVARCHAR(MAX),@TutarString NVARCHAR(MAX)

			SET @TutarString = CAST(@Tutar AS NVARCHAR(MAX))
			SET @GonderenHesapNoString = CAST(@GonderenHesapNo AS NVARCHAR(MAX))
			SET @AlanHesapNoString = CAST(@AlanHesapNo AS NVARCHAR(MAX))

			-- Dinamic yap�l� olan bankadan mevcut bakiye al�n�p de�i�kene atand�
			SET @HesaptakiParaString = 'SELECT @HesaptakiPara = Bakiye FROM ' + @BankaKimden + ' WHERE HesapNo = ' + @GonderenHesapNoString
			EXEC sp_executesql @HesaptakiParaString, N'@HesaptakiPara Nvarchar(max) OUTPUT',
			@HesaptakiPara = @HesaptakiPara OUTPUT

			-- Hesapta g�ndermek istenen para yoksa i�lem iptali sa�land�
			IF @Tutar > @HesaptakiPara
				BEGIN
					PRINT CAST(@GonderenHesapNo AS NVARCHAR(MAX)) + ' numaral� hesapta g�nderilmek istenenden az para mevcuttur.'
					ROLLBACK
				END
			ELSE
				BEGIN
				        -- 2 durum kontrol alt�na al�nd� 
						-- 1.durum kullan�c� ayn� bankadaki kendi hesab�na para aktaramaz 
						-- 2.durum kullan�c� olmayan bir hesap no ya para att��� zaman geri iade sa�lanmas� kontrol� yap�ld� 
						DECLARE @GonderenHesapKontrol NVARCHAR(MAX),@AlanHesapKontrol NVARCHAR(MAX),@GonderenHesapNoControl INT,@AlanHesapNoControl INT
						SET @GonderenHesapKontrol = 'SELECT @GonderenHesapNoControl = HesapNo FROM ' + @BankaKimden + ' WHERE HesapNo = ' + @GonderenHesapNoString
						EXEC sp_executesql @GonderenHesapKontrol, 
						N'@GonderenHesapNoControl INT OUTPUT',
						   @GonderenHesapNoControl = @GonderenHesapNoControl OUTPUT
						SET @AlanHesapKontrol = 'SELECT @AlanHesapNoControl = HesapNo FROM ' + @BankaKime + ' WHERE HesapNo = ' + @AlanHesapNoString
						EXEC sp_executesql @AlanHesapKontrol, 
						N'@AlanHesapNoControl INT OUTPUT',
						   @AlanHesapNoControl = @AlanHesapNoControl OUTPUT  
						
						----------------------------- 1.Kontrol i�in haz�rl�klar yap�ld� (Hesap no lar de�i�kenlere aktar�ld�) ----------------------------

						DECLARE @GonderenNullKontrol NVARCHAR(max),@BankaKimdenRowCount INT
						SET @GonderenNullKontrol =  'select @BankaKimdenRowCount = count(1) where exists (select * from ' + @BankaKimden + ' Where HesapNo = ' + @GonderenHesapNoString + ' )'
						EXEC sp_executesql @GonderenNullKontrol, N'@BankaKimdenRowCount INT OUTPUT',
						@BankaKimdenRowCount = @BankaKimdenRowCount OUTPUT

						DECLARE @AlanNullKontrol NVARCHAR(max),@BankaKimeRowCount INT
						SET @AlanNullKontrol =  'select @BankaKimeRowCount = count(1) where exists (select * from ' + @BankaKime + ' Where HesapNo = ' + @AlanHesapNoString + ' )'
						EXEC sp_executesql @AlanNullKontrol, N'@BankaKimeRowCount INT OUTPUT',
						@BankaKimeRowCount = @BankaKimeRowCount OUTPUT

						----------------------------- 2.Kontrol i�in haz�rl�klar yap�ld� (Hesap no lara de�i�kenlere aktar�ld�) ----------------------------
						-------------- !!! count ile 1 ve 0 de�erleri d�nd�r�ld� veri varsa bir �yle bir hesap yoksa de�i�kene 0 de�eri atand� --------------------


						-- Hesap yoksa yani count 0 d�nd�yse �yle bir hesap yoktur ve i�lem iptal edilip kullan�c�ya mesaj verilir
						IF (@BankaKimdenRowCount = 0 OR @BankaKimeRowCount = 0)
							BEGIN
								PRINT 'G�nderen veya alan hesap ge�erli de�il Tekrar kontrol ediniz'
								ROLLBACK
							END
						-- Ki�inin ayn� bankadaki ayn� hesab�na para atmas� engellendi
						ELSE IF(@GonderenHesapNo = @AlanHesapNo)
							BEGIN
								PRINT 'Ayn� bankadaki kendi hesab�n�za para aktaramazs�n�z'
								ROLLBACK
							END
						-- E�er bu a�amalar ge�ildiyse para transferi yap�l�p i�lemler commit edilir
						ELSE
							BEGIN
								DECLARE @GonderenBanka NVARCHAR(MAX),@AlanBanka NVARCHAR(MAX)
								SET @GonderenBanka = 'UPDATE ' + @BankaKimden + ' SET Bakiye = Bakiye - ' + @TutarString + ' WHERE HesapNo = ' + @GonderenHesapNoString
								SET @AlanBanka = 'UPDATE ' + @BankaKime + ' SET Bakiye = Bakiye + ' + @TutarString + ' WHERE HesapNo = ' + @AlanHesapNoString
								EXEC(@GonderenBanka)
								EXEC(@AlanBanka)
							
								PRINT @BankaKimden + ' s�ndaki ' + CAST(@GonderenHesapNo AS NVARCHAR(MAX)) + ' numaral� hesaptan ' + @BankaKime 
								+ ' ndaki ' + CAST(@AlanHesapNo AS NVARCHAR(MAX)) + ' numaral� hesaba ' + CAST(@Tutar AS NVARCHAR(MAX)) 
								+ ' de�erinde para havale edilmi�tir.'

								PRINT 'Son de�erler;'

								DECLARE @GonderenBakiyeKalan NVARCHAR(MAX),@AlanBakiyeKalan NVARCHAR(MAX)
							    SET @GonderenBakiyeKalan = 'SELECT @GonderenBakiye = Bakiye FROM ' + @BankaKimden + ' WHERE HesapNo = ' + @GonderenHesapNoString
								EXEC sp_executesql @GonderenBakiyeKalan, N'@GonderenBakiye INT OUTPUT',
									@GonderenBakiye = @GonderenBakiye OUTPUT
							    SET @AlanBakiyeKalan = 'SELECT @AlanBakiye = Bakiye FROM ' + @BankaKime + ' WHERE HesapNo = ' + @AlanHesapNoString
								EXEC sp_executesql @AlanBakiyeKalan, N'@AlanBakiye INT OUTPUT',
									@AlanBakiye = @AlanBakiye OUTPUT

							    PRINT @BankaKimden + ' s�ndaki ' + @GonderenHesapNoString + ' numaral� hesapta kalan bakiye :'
							    + CAST(@GonderenBakiye AS NVARCHAR(MAX))
							    PRINT @BankaKime + ' s�ndaki ' + @AlanHesapNoString + ' numaral� hesapta kalan bakiye :'
							    + CAST(@AlanBakiye AS NVARCHAR(MAX))
			
								COMMIT
						END
	
				END		
END

EXEC sp_HavaleYap 'ABanka','BBanka',10,30,100
EXEC sp_HavaleYap 'BBanka','ABanka',30,10,300
EXEC sp_HavaleYap 'BBanka','BBanka',30,40,200
EXEC sp_HavaleYap 'ABanka','ABanka',20,10,400
EXEC sp_HavaleYap 'ABanka','ABanka',10,30,100
EXEC sp_HavaleYap 'ABanka','ABanka',40,10,100
EXEC sp_HavaleYap 'ABanka','ABanka',10,10,100
EXEC sp_HavaleYap 'ABanka','BBanka',20,40,5000 


EXEC sp_HavaleYap 'ABanka','CBanka',20,60,300
EXEC sp_HavaleYap 'CBanka','ABanka',50,10,400
EXEC sp_HavaleYap 'CBanka','CBanka',50,60,500
EXEC sp_HavaleYap 'CBanka','CBanka',50,40,500
EXEC sp_HavaleYap 'CBanka','CBanka',60,50,40000
EXEC sp_HavaleYap 'CBanka','CBanka',60,60,400

SELECT * FROM ABanka
SELECT * FROM BBanka
SELECT * FROM CBanka
SELECT * FROM ABankaRaporTablosu
SELECT * FROM BBankaRaporTablosu
SELECT * FROM CBankaRaporTablosu

DELETE FROM ABanka
DELETE FROM BBanka
DELETE FROM CBanka
DELETE FROM ABankaRaporTablosu
DELETE FROM BBankaRaporTablosu
DELETE FROM CBankaRaporTablosu


-- Trigger b�l�m�

CREATE TABLE ABankaRaporTablosu
(
	Id INT PRIMARY KEY IDENTITY(1,1),
	Rapor NVARCHAR(MAX)
)


CREATE TRIGGER TrgABankaRapor
ON ABanka
AFTER UPDATE
AS 
DECLARE @EskiBakiye NVARCHAR(MAX),@YeniBakiye NVARCHAR(MAX),@Tutar MONEY
		,@GonderenHesapNo NVARCHAR(MAX),@AlanHesapNo NVARCHAR(Max)
	SELECT @EskiBakiye = Bakiye from deleted
	SELECT @YeniBakiye = Bakiye from inserted
	SELECT @GonderenHesapNo =  HesapNo  FROM deleted
	SELECT @AlanHesapNo = HesapNo FROM inserted
	SET @Tutar = CAST(@EskiBakiye AS MONEY) - CAST(@YeniBakiye AS MONEY)
IF @Tutar < 0
	BEGIN 
		  INSERT ABankaRaporTablosu VALUES ('A bankas�ndaki ' + @AlanHesapNo + ' nolu hesap '
		                                 + CAST(ABS(@Tutar) AS NVARCHAR) +' TL alarak ' + @EskiBakiye + ' TL den ' + 
										 + @YeniBakiye + ' TL olarak '
										 + CAST(GETDATE() AS NVARCHAR(MAX)) + ' TAR�H�NDE HESAP G�NCELLENM��T�R.')
	END
ELSE
	BEGIN
		INSERT ABankaRaporTablosu VALUES ('A bankas�ndaki ' + @GonderenHesapNo + ' nolu hesap ' 
		                                 + @EskiBakiye + ' TL den ' + CAST(@Tutar AS NVARCHAR)
										 +' TL g�ndererek ' + @YeniBakiye + ' TL olarak '
										 + CAST(GETDATE() AS NVARCHAR(MAX)) + ' TAR�H�NDE HESAP G�NCELLENM��T�R.')
	END



CREATE TABLE BBankaRaporTablosu
(
	--Id INT PRIMARY KEY IDENTITY(1,1),
	Rapor NVARCHAR(MAX)
)


CREATE TRIGGER TrgBBankaRapor
ON BBanka 
AFTER UPDATE
AS 
DECLARE @EskiBakiye NVARCHAR(MAX),@YeniBakiye NVARCHAR(MAX),@Tutar MONEY
		,@GonderenHesapNo NVARCHAR(MAX),@AlanHesapNo NVARCHAR(Max)
	SELECT @EskiBakiye = Bakiye from deleted
	SELECT @YeniBakiye = Bakiye from inserted
	SELECT @GonderenHesapNo = HesapNo FROM deleted
	SELECT @AlanHesapNo = HesapNo FROM inserted
	SET @Tutar = CAST(@EskiBakiye AS MONEY) - CAST(@YeniBakiye AS MONEY)
IF @Tutar < 0
	BEGIN 
		INSERT BBankaRaporTablosu VALUES ('B bankas�ndaki ' + @AlanHesapNo + ' nolu hesap ' 
										 + CAST(ABS(@Tutar) AS NVARCHAR) +' TL alarak ' 
										 + @EskiBakiye + ' TL den ' + @YeniBakiye + ' TL olarak '
										 + CAST(GETDATE() AS NVARCHAR(MAX)) + ' TAR�H�NDE HESAP G�NCELLENM��T�R.')
	END
ELSE
	BEGIN
		INSERT BBankaRaporTablosu VALUES ('B bankas�ndaki ' + @GonderenHesapNo + ' nolu hesap ' 
										 +  @EskiBakiye + ' TL den ' + CAST(@Tutar AS NVARCHAR)
										 +' TL g�ndererek ' + @YeniBakiye + ' TL olarak '
										 + CAST(GETDATE() AS NVARCHAR(MAX)) + ' TAR�H�NDE HESAP G�NCELLENM��T�R.')
	END



CREATE TABLE CBankaRaporTablosu
(
	--Id INT PRIMARY KEY IDENTITY(1,1),
	Rapor NVARCHAR(MAX)
)

CREATE TRIGGER TrgCBankaRapor
ON CBanka
AFTER UPDATE
AS 
DECLARE @EskiBakiye NVARCHAR(MAX),@YeniBakiye NVARCHAR(MAX),@Tutar MONEY
		,@GonderenHesapNo NVARCHAR(MAX),@AlanHesapNo NVARCHAR(Max)
	SELECT @EskiBakiye = Bakiye from deleted
	SELECT @YeniBakiye = Bakiye from inserted
	SELECT @GonderenHesapNo =  HesapNo  FROM deleted
	SELECT @AlanHesapNo = HesapNo FROM inserted
	SET @Tutar = CAST(@EskiBakiye AS MONEY) - CAST(@YeniBakiye AS MONEY)
IF @Tutar < 0
	BEGIN 
		  INSERT CBankaRaporTablosu VALUES ('C bankas�ndaki ' + @AlanHesapNo + ' nolu hesap '
		                                 + CAST(ABS(@Tutar) AS NVARCHAR) +' TL alarak ' + @EskiBakiye + ' TL den ' + 
										 + @YeniBakiye + ' TL olarak '
										 + CAST(GETDATE() AS NVARCHAR(MAX)) + ' TAR�H�NDE HESAP G�NCELLENM��T�R.')
	END
ELSE
	BEGIN
		INSERT CBankaRaporTablosu VALUES ('C bankas�ndaki ' + @GonderenHesapNo + ' nolu hesap ' 
		                                 + @EskiBakiye + ' TL den ' + CAST(@Tutar AS NVARCHAR)
										 +' TL g�ndererek ' + @YeniBakiye + ' TL olarak '
										 + CAST(GETDATE() AS NVARCHAR(MAX)) + ' TAR�H�NDE HESAP G�NCELLENM��T�R.')
	END

--SELECT TABLE_NAME INTO ALLDATA FROM INFORMATION_SCHEMA.TABLES 
--WHERE TABLE_TYPE = 'BASE TABLE' AND TABLE_NAME <> 'ALLDATA'
--SELECT * FROM ALLDATA  
--ALTER TABLE ALLDATA ADD ID INT PRIMARY KEY IDENTITY(1,1)



-- Tablodaki bir de�eri de�i�kene atama

--DECLARE @HesaptakiParaString NVARCHAR(max),@BankaName  NVARCHAR(max),@Bak Nvarchar(max)
--SET @BankaName = 'ABanka'
--SET @HesaptakiParaString = 'SELECT @Bak = Bakiye FROM ' + @BankaName + ' WHERE HesapNo = 10'
--EXEC sp_executesql @HesaptakiParaString, N'@Bak Nvarchar(max) OUTPUT',
--@Bak = @Bak OUTPUT
--PRINT @Bak



--DECLARE @Bak1 NVARCHAR(MAX),@Bank NVARCHAR(MAX),@deneme NVARCHAR(max),@Total INT
--SET @Bank = 'ABanka'
--Set @Bak1 = '30'
--set @deneme =  'select @Total = count(1) where exists (select * from ' + @Bank + ' Where HesapNo = ' + @Bak1 + ' )'
--EXEC sp_executesql @deneme, N'@Total INT OUTPUT',
--@Total = @Total OUTPUT
--PRINT @Total