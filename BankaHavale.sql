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
			-- Deðiþkenler tanýmlandý ve deðiþkene sorgu deðeri atmak için bazý veriler geçici olarak nvarchar a dönüþtürüldü
			DECLARE @GonderenBakiye INT,@AlanBakiye INT,@HesaptakiPara MONEY,
			@GonderenHesapNoString NVARCHAR(MAX),@AlanHesapNoString NVARCHAR(MAX),
			@HesaptakiParaString NVARCHAR(MAX),@TutarString NVARCHAR(MAX)

			SET @TutarString = CAST(@Tutar AS NVARCHAR(MAX))
			SET @GonderenHesapNoString = CAST(@GonderenHesapNo AS NVARCHAR(MAX))
			SET @AlanHesapNoString = CAST(@AlanHesapNo AS NVARCHAR(MAX))

			-- Dinamic yapýlý olan bankadan mevcut bakiye alýnýp deðiþkene atandý
			SET @HesaptakiParaString = 'SELECT @HesaptakiPara = Bakiye FROM ' + @BankaKimden + ' WHERE HesapNo = ' + @GonderenHesapNoString
			EXEC sp_executesql @HesaptakiParaString, N'@HesaptakiPara Nvarchar(max) OUTPUT',
			@HesaptakiPara = @HesaptakiPara OUTPUT

			-- Hesapta göndermek istenen para yoksa iþlem iptali saðlandý
			IF @Tutar > @HesaptakiPara
				BEGIN
					PRINT CAST(@GonderenHesapNo AS NVARCHAR(MAX)) + ' numaralý hesapta gönderilmek istenenden az para mevcuttur.'
					ROLLBACK
				END
			ELSE
				BEGIN
				        -- 2 durum kontrol altýna alýndý 
						-- 1.durum kullanýcý ayný bankadaki kendi hesabýna para aktaramaz 
						-- 2.durum kullanýcý olmayan bir hesap no ya para attýðý zaman geri iade saðlanmasý kontrolü yapýldý 
						DECLARE @GonderenHesapKontrol NVARCHAR(MAX),@AlanHesapKontrol NVARCHAR(MAX),@GonderenHesapNoControl INT,@AlanHesapNoControl INT
						SET @GonderenHesapKontrol = 'SELECT @GonderenHesapNoControl = HesapNo FROM ' + @BankaKimden + ' WHERE HesapNo = ' + @GonderenHesapNoString
						EXEC sp_executesql @GonderenHesapKontrol, 
						N'@GonderenHesapNoControl INT OUTPUT',
						   @GonderenHesapNoControl = @GonderenHesapNoControl OUTPUT
						SET @AlanHesapKontrol = 'SELECT @AlanHesapNoControl = HesapNo FROM ' + @BankaKime + ' WHERE HesapNo = ' + @AlanHesapNoString
						EXEC sp_executesql @AlanHesapKontrol, 
						N'@AlanHesapNoControl INT OUTPUT',
						   @AlanHesapNoControl = @AlanHesapNoControl OUTPUT  
						
						----------------------------- 1.Kontrol için hazýrlýklar yapýldý (Hesap no lar deðiþkenlere aktarýldý) ----------------------------

						DECLARE @GonderenNullKontrol NVARCHAR(max),@BankaKimdenRowCount INT
						SET @GonderenNullKontrol =  'select @BankaKimdenRowCount = count(1) where exists (select * from ' + @BankaKimden + ' Where HesapNo = ' + @GonderenHesapNoString + ' )'
						EXEC sp_executesql @GonderenNullKontrol, N'@BankaKimdenRowCount INT OUTPUT',
						@BankaKimdenRowCount = @BankaKimdenRowCount OUTPUT

						DECLARE @AlanNullKontrol NVARCHAR(max),@BankaKimeRowCount INT
						SET @AlanNullKontrol =  'select @BankaKimeRowCount = count(1) where exists (select * from ' + @BankaKime + ' Where HesapNo = ' + @AlanHesapNoString + ' )'
						EXEC sp_executesql @AlanNullKontrol, N'@BankaKimeRowCount INT OUTPUT',
						@BankaKimeRowCount = @BankaKimeRowCount OUTPUT

						----------------------------- 2.Kontrol için hazýrlýklar yapýldý (Hesap no lara deðiþkenlere aktarýldý) ----------------------------
						-------------- !!! count ile 1 ve 0 deðerleri döndürüldü veri varsa bir öyle bir hesap yoksa deðiþkene 0 deðeri atandý --------------------


						-- Hesap yoksa yani count 0 döndüyse öyle bir hesap yoktur ve iþlem iptal edilip kullanýcýya mesaj verilir
						IF (@BankaKimdenRowCount = 0 OR @BankaKimeRowCount = 0)
							BEGIN
								PRINT 'Gönderen veya alan hesap geçerli deðil Tekrar kontrol ediniz'
								ROLLBACK
							END
						-- Kiþinin ayný bankadaki ayný hesabýna para atmasý engellendi
						ELSE IF(@GonderenHesapNo = @AlanHesapNo)
							BEGIN
								PRINT 'Ayný bankadaki kendi hesabýnýza para aktaramazsýnýz'
								ROLLBACK
							END
						-- Eðer bu aþamalar geçildiyse para transferi yapýlýp iþlemler commit edilir
						ELSE
							BEGIN
								DECLARE @GonderenBanka NVARCHAR(MAX),@AlanBanka NVARCHAR(MAX)
								SET @GonderenBanka = 'UPDATE ' + @BankaKimden + ' SET Bakiye = Bakiye - ' + @TutarString + ' WHERE HesapNo = ' + @GonderenHesapNoString
								SET @AlanBanka = 'UPDATE ' + @BankaKime + ' SET Bakiye = Bakiye + ' + @TutarString + ' WHERE HesapNo = ' + @AlanHesapNoString
								EXEC(@GonderenBanka)
								EXEC(@AlanBanka)
							
								PRINT @BankaKimden + ' sýndaki ' + CAST(@GonderenHesapNo AS NVARCHAR(MAX)) + ' numaralý hesaptan ' + @BankaKime 
								+ ' ndaki ' + CAST(@AlanHesapNo AS NVARCHAR(MAX)) + ' numaralý hesaba ' + CAST(@Tutar AS NVARCHAR(MAX)) 
								+ ' deðerinde para havale edilmiþtir.'

								PRINT 'Son deðerler;'

								DECLARE @GonderenBakiyeKalan NVARCHAR(MAX),@AlanBakiyeKalan NVARCHAR(MAX)
							    SET @GonderenBakiyeKalan = 'SELECT @GonderenBakiye = Bakiye FROM ' + @BankaKimden + ' WHERE HesapNo = ' + @GonderenHesapNoString
								EXEC sp_executesql @GonderenBakiyeKalan, N'@GonderenBakiye INT OUTPUT',
									@GonderenBakiye = @GonderenBakiye OUTPUT
							    SET @AlanBakiyeKalan = 'SELECT @AlanBakiye = Bakiye FROM ' + @BankaKime + ' WHERE HesapNo = ' + @AlanHesapNoString
								EXEC sp_executesql @AlanBakiyeKalan, N'@AlanBakiye INT OUTPUT',
									@AlanBakiye = @AlanBakiye OUTPUT

							    PRINT @BankaKimden + ' sýndaki ' + @GonderenHesapNoString + ' numaralý hesapta kalan bakiye :'
							    + CAST(@GonderenBakiye AS NVARCHAR(MAX))
							    PRINT @BankaKime + ' sýndaki ' + @AlanHesapNoString + ' numaralý hesapta kalan bakiye :'
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


-- Trigger bölümü

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
		  INSERT ABankaRaporTablosu VALUES ('A bankasýndaki ' + @AlanHesapNo + ' nolu hesap '
		                                 + CAST(ABS(@Tutar) AS NVARCHAR) +' TL alarak ' + @EskiBakiye + ' TL den ' + 
										 + @YeniBakiye + ' TL olarak '
										 + CAST(GETDATE() AS NVARCHAR(MAX)) + ' TARÝHÝNDE HESAP GÜNCELLENMÝÞTÝR.')
	END
ELSE
	BEGIN
		INSERT ABankaRaporTablosu VALUES ('A bankasýndaki ' + @GonderenHesapNo + ' nolu hesap ' 
		                                 + @EskiBakiye + ' TL den ' + CAST(@Tutar AS NVARCHAR)
										 +' TL göndererek ' + @YeniBakiye + ' TL olarak '
										 + CAST(GETDATE() AS NVARCHAR(MAX)) + ' TARÝHÝNDE HESAP GÜNCELLENMÝÞTÝR.')
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
		INSERT BBankaRaporTablosu VALUES ('B bankasýndaki ' + @AlanHesapNo + ' nolu hesap ' 
										 + CAST(ABS(@Tutar) AS NVARCHAR) +' TL alarak ' 
										 + @EskiBakiye + ' TL den ' + @YeniBakiye + ' TL olarak '
										 + CAST(GETDATE() AS NVARCHAR(MAX)) + ' TARÝHÝNDE HESAP GÜNCELLENMÝÞTÝR.')
	END
ELSE
	BEGIN
		INSERT BBankaRaporTablosu VALUES ('B bankasýndaki ' + @GonderenHesapNo + ' nolu hesap ' 
										 +  @EskiBakiye + ' TL den ' + CAST(@Tutar AS NVARCHAR)
										 +' TL göndererek ' + @YeniBakiye + ' TL olarak '
										 + CAST(GETDATE() AS NVARCHAR(MAX)) + ' TARÝHÝNDE HESAP GÜNCELLENMÝÞTÝR.')
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
		  INSERT CBankaRaporTablosu VALUES ('C bankasýndaki ' + @AlanHesapNo + ' nolu hesap '
		                                 + CAST(ABS(@Tutar) AS NVARCHAR) +' TL alarak ' + @EskiBakiye + ' TL den ' + 
										 + @YeniBakiye + ' TL olarak '
										 + CAST(GETDATE() AS NVARCHAR(MAX)) + ' TARÝHÝNDE HESAP GÜNCELLENMÝÞTÝR.')
	END
ELSE
	BEGIN
		INSERT CBankaRaporTablosu VALUES ('C bankasýndaki ' + @GonderenHesapNo + ' nolu hesap ' 
		                                 + @EskiBakiye + ' TL den ' + CAST(@Tutar AS NVARCHAR)
										 +' TL göndererek ' + @YeniBakiye + ' TL olarak '
										 + CAST(GETDATE() AS NVARCHAR(MAX)) + ' TARÝHÝNDE HESAP GÜNCELLENMÝÞTÝR.')
	END

--SELECT TABLE_NAME INTO ALLDATA FROM INFORMATION_SCHEMA.TABLES 
--WHERE TABLE_TYPE = 'BASE TABLE' AND TABLE_NAME <> 'ALLDATA'
--SELECT * FROM ALLDATA  
--ALTER TABLE ALLDATA ADD ID INT PRIMARY KEY IDENTITY(1,1)



-- Tablodaki bir deðeri deðiþkene atama

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