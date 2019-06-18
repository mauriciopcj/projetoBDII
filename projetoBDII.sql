--DROP TABLE Grupo;
CREATE TABLE Grupo (
	nome varchar(50) NOT NULL,
	matricula char(11) NOT NULL
);

INSERT INTO Grupo VALUES ('Mauricio Pereira', '20181370027');
INSERT INTO Grupo VALUES ('Renato Borges', '20171370013');
INSERT INTO Grupo VALUES ('Romero Reis', '20181370009');

--DROP TABLE Conta;
CREATE TABLE Conta (
	numConta char(11) NOT NULL CHECK(char_length(numConta)=11),
	dig char(1) NOT NULL CHECK(dig SIMILAR TO '([0-9]|&)'),
	nome varchar(50) NOT NULL,
	tipo char(1) NOT NULL CHECK(tipo SIMILAR TO '(A|S)'),
	ativa char(1) NOT NULL CHECK(ativa SIMILAR TO '(S|N)'),
	CONSTRAINT PK_conta PRIMARY KEY (numConta)
);

--DROP TABLE Saldos;
CREATE TABLE Saldos (
	numConta char(11) NOT NULL,
	ano int NOT NULL,
	saldo numeric(9,2) NOT NULL,
	CONSTRAINT PK_saldos PRIMARY KEY (numConta, ano),
	CONSTRAINT FK_saldos_conta FOREIGN KEY (numConta) REFERENCES Conta (numConta)
);

--DROP TABLE DebCred;
CREATE TABLE DebCred (
	numConta char(11) NOT NULL,
	mesAno char(6) NOT NULL,
	credito numeric(11,2) NOT NULL,
	debito numeric(11,2) NOT NULL,
	CONSTRAINT PK_debcred PRIMARY KEY (numConta, mesAno),
	CONSTRAINT FK_debcred_conta FOREIGN KEY (numConta) REFERENCES Conta (numConta)
);

--DROP TABLE MovDebCred;
CREATE TABLE MovDebCred (
	numConta char(11) NOT NULL,
	nsu int NOT NULL GENERATED BY DEFAULT AS IDENTITY, 
	dig char(1) NOT NULL,
	data timestamp NOT NULL,
	debCred char(1) NOT NULL CHECK(debCred SIMILAR TO '(D|C)'),
	valor numeric(11,2) NOT NULL,
	CONSTRAINT PK_movdebcred PRIMARY KEY (numConta, nsu)
);

/* VIEW - 7.2 */

CREATE VIEW viu as (SELECT
	
	debcred.numconta,
	
	SUBSTRING(debcred.mesano FROM 3 FOR 4) as ano,
	
	saldos.saldo AS "anterior", 
	
	SUM(debCred.credito) AS "totCred", 
	
	SUM(debCred.debito) AS "totDeb", 
	
	(SUM(debCred.credito) - SUM(debCred.debito)) AS "atual"
	
FROM Saldos RIGHT OUTER JOIN DebCred ON Saldos.numConta = DebCred.numConta
	
	where CAST(substring(debCred.mesAno FROM 3 FOR 4) AS integer) = CAST(date_part('year', CURRENT_DATE) as integer)
	
GROUP BY 1,2,3
	);

/* TRIGGER  */


CREATE OR REPLACE FUNCTION has_superior_accounts()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
	DECLARE
		total_superior_accounts smallint;
    BEGIN
		total_superior_accounts := (
			SELECT COUNT(*) FROM conta
			WHERE numconta LIKE get_last_account_level(NEW.numconta)
		);
		IF total_superior_accounts < 1 AND get_account_level(NEW.numconta) > 1 THEN
			RAISE EXCEPTION E'Account % does not have any superiors', NEW.numconta;
		END IF;
		RETURN NEW;
	END;
$$;


CREATE TRIGGER validate_account_number BEFORE INSERT ON conta
FOR EACH ROW EXECUTE PROCEDURE has_superior_accounts();

/* STORED PROCEDURE - 7.3.b */

CREATE PROCEDURE transporte(anoS integer)
AS $$
DECLARE
	numconta varchar(11) :='';
	saldo numeric := 0;
	cred numeric := 0;
	deb numeric := 0;
	total numeric := 0;
	linha RECORD;
BEGIN
	FOR linha in SELECT debcred.numconta as conta, saldos.saldo as sald, sum(debcred.credito) as credito, sum(debcred.debito) as debito
	FROM saldos RIGHT OUTER JOIN debcred ON saldos.numconta = debcred.numconta
	WHERE CAST(SUBSTRING(debcred.mesano FROM 3 FOR 4) AS integer) = anoS
	group by 1,2
	LOOP
		IF (linha.sald != NULL) THEN
			saldo = linha.sald;
		END IF;
		numconta := linha.conta;
		cred := linha.credito;
		deb := linha.debito;
		total := saldo+cred-deb;
		INSERT INTO saldos (numconta, ano, saldo)
		VALUES (numconta, anoS+1, total);
	END LOOP;
END; $$
LANGUAGE 'plpgsql';

/* STORED PROCEDURE - 7.3.c */

/* RETURN TRUE OR FALSE

CREATE OR REPLACE FUNCTION critica (mes integer, ano integer)
RETURNS BOOLEAN AS $$
DECLARE
	numconta varchar(11) :='';
	dig numeric := 0;
	tipo varchar(1) := '';
BEGIN
	SELECT INTO numconta,dig  mdc.numconta, mdc.dig
	FROM movdebcred as mdc
	WHERE CAST(to_char(mdc.data, 'MM') as integer) = mes 
	AND CAST(to_char(mdc.data, 'YYYY') as integer) = ano;
	SELECT INTO tipo conta.tipo 
	FROM conta 
	WHERE conta.numconta = numconta;
	IF numconta = null THEN
		RETURN FALSE;
	ELSIF verifica_digito(numconta) != dig THEN
		RETURN FALSE;
	ELSIF  tipo = 'S' THEN
		RETURN FALSE;
	END IF;
	RETURN TRUE;
END; 
$$ LANGUAGE 'plpgsql'; */

/*
SELECT identificador AS "NSU", numero_conta AS "Numero Inserido",
	dig_insert AS "Digito Inserido",dig_ok AS "Digito Correto",tipo_conta AS "Tipo" 
FROM critica(4,2019);
*/

-- DROP FUNCTION critica(integer,integer)

CREATE OR REPLACE FUNCTION critica (mes integer, ano integer)
RETURNS TABLE (identificador integer,
			   numero_conta char(11),  
			   dig_insert char(1), 
			   dig_ok varchar(1), 
			   tipo_conta char(1))
AS $$
DECLARE
BEGIN
	RETURN QUERY SELECT mdc.nsu, mdc.numconta, mdc.dig, verifica_digito(mdc.numconta), conta.tipo
	FROM (SELECT * FROM MovDebCred WHERE CAST(to_char(data, 'MM') as integer) = mes
	AND CAST(to_char(data, 'YYYY') as integer) = ano ORDER BY numconta, debcred) AS mdc 
	LEFT OUTER JOIN conta ON conta.numconta = mdc.numconta
	WHERE conta.tipo = 'S' OR mdc.dig <> verifica_digito(mdc.numconta) OR conta.numconta IS NULL;
END; 
$$ LANGUAGE 'plpgsql';

/* STORED FUNCTION - 7.4.a */

CREATE OR REPLACE FUNCTION verifica_digito (numero varchar)
RETURNS varchar
AS $$
DECLARE
	mascara varchar := '27654327654';
	soma integer := 0;
	resto integer;
	digito varchar;
BEGIN
	FOR i IN 1..11 LOOP
		soma = soma + CAST(substring(numero from i for 1) AS integer) * CAST(substring(mascara from i for 1) AS integer);
	END LOOP;
	resto := soma % 11;
	digito := 11 - resto;
	IF digito = '10' THEN
		digito := '0';
	ELSIF digito = '11' THEN
		digito := '&';
	END IF;
	RETURN digito;
END; 
$$ LANGUAGE 'plpgsql';

/* STORED FUNCTION - 7.4.b */

CREATE OR REPLACE FUNCTION saldo_atual (numero varchar, mes integer, anoNovo int)
RETURNS TABLE (
	saldo_anterior numeric(9,2),
	tot_credito numeric(9,2),
	tot_debito numeric(9,2),
	saldo_atual numeric(9,2)
)
AS $$
BEGIN
	RETURN QUERY
		SELECT saldos.saldo AS "anterior", 
			SUM(debCred.credito) AS "totCred", 
			SUM(debCred.debito) AS "totDeb", 
			saldos.saldo + (debCred.credito - debCred.debito) AS "atual"
		FROM Saldos JOIN DebCred ON Saldos.numConta = DebCred.numConta
		WHERE saldos.ano = anoNovo
			AND debCred.numConta = numero
			AND CAST(substring(debCred.mesAno FROM 0 FOR 2) AS integer) <= mes
			AND CAST(substring(debCred.mesAno FROM 2 FOR 4) AS integer) = anoNovo
		GROUP BY 1, 4;
		
END; 
$$ LANGUAGE 'plpgsql';

-- TESTES EM AVALIACAO

/*
SELECT * FROM MovDebCred;

SELECT cc.numconta,  date_part('year', cc.data), cc.debcred, SUM(cc.valor),dd.debcred, SUM(dd.valor)
FROM MovDebCred AS cc JOIN MovDebCred AS dd ON cc.numconta = dd.numconta
WHERE date_part('month', cc.data) = 1 AND cc.numconta = '11010100000' AND dd.numconta = '11010100000' AND cc.debcred = 'C' AND dd.debcred = 'D'
GROUP BY cc.numconta, cc.debcred,dd.debcred , date_part('year', cc.data),cc.debcred
ORDER BY cc.numconta, date_part('year', cc.data);

SELECT cc.numconta,  date_part('year', cc.data), cc.debcred, SUM(cc.valor)
FROM MovDebCred AS cc
WHERE date_part('month', cc.data) = 1 AND cc.numconta = '11010100000'
GROUP BY cc.numconta, cc.debcred, date_part('year', cc.data),cc.debcred
ORDER BY cc.numconta, date_part('year', cc.data);

SELECT * FROM MovDebCred


*/
CREATE OR REPLACE PROCEDURE atualizaTabelaDebCred(
	mesS integer,
	anoS integer
)
LANGUAGE 'plpgsql'
AS $$
	DECLARE
		linha RECORD;
		selected_mesano varchar := CONCAT(
			LPAD(CAST(mesS AS varchar), 2, '0'), CAST(anoS AS varchar)
		);
		total int := 0;
	BEGIN
		FOR linha IN SELECT mv.numconta AS numconta, mv.debcred, SUM(mv.valor) AS total
			FROM MovDebCred AS mv JOIN conta AS conta ON conta.numconta = mv.numconta
			WHERE date_part('month', mv.data) = mesS AND date_part('year', mv.data) = anoS AND
			conta.tipo = 'A' AND conta.ativa = 'S' AND mv.debcred = 'C'
			GROUP BY mv.numconta, mv.debcred
			ORDER BY numconta LOOP
                SELECT INTO total SUM(valor) FROM MovDebCred
                    WHERE date_part('month', data) = mesS AND date_part('year', data) = anoS AND
                    numConta = linha.numConta AND debcred = 'D';
                INSERT INTO DebCred (numConta, mesano, credito, debito) 
                    VALUES (
                        linha.numConta,
                        selected_mesano,
                        linha.total,
                        total
                    );
		END LOOP;
		IF mesS = 12 THEN
			CALL transporte(anoS);
		END IF;
	END;
$$;



CREATE OR REPLACE FUNCTION update_superior_accounts()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
	DECLARE
		superior_conta varchar := get_last_account_level(NEW.numconta);
    BEGIN
		IF get_account_level(NEW.numconta) = 1 THEN
			RETURN NEW;
		END IF;
		INSERT INTO DebCred AS dc (numConta, mesano, credito, debito) 
			VALUES (
				superior_conta,
				NEW.mesano,
				NEW.credito,
				NEW.debito
			) ON CONFLICT (numConta, mesano) DO UPDATE
				SET credito = dc.credito + NEW.credito, debito = dc.debito + NEW.debito;
		RETURN NEW;
	END;
$$;


CREATE TRIGGER validate_account_number BEFORE INSERT OR UPDATE ON DebCred
FOR EACH ROW EXECUTE PROCEDURE update_superior_accounts();
