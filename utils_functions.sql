

/* FORMATA NUMERO DE CONTA DE INTEIRO PARA STRING COM MASCARA (pontos) */

CREATE OR REPLACE FUNCTION format_account_number( account_number bigint )
RETURNS VARCHAR
LANGUAGE 'plpgsql'
AS $$
	DECLARE
		mask VARCHAR := 'X.X.XX.XX.XXX.XX';
		formated_value VARCHAR := '';
		account_number_char VARCHAR;
		interator integer := 1;
	BEGIN
		account_number_char = CAST(account_number AS VARCHAR);
		FOR i IN 1..16 LOOP
			IF substring(mask from i for 1) = 'X' THEN
				formated_value = CONCAT(
					formated_value,
					substring(account_number_char from interator for 1)
				);
				interator = interator + 1;
			ELSE
				formated_value = CONCAT(formated_value, '.');
			END IF;
		END LOOP;
		RETURN formated_value;
	END;
$$;

/* REMOVE FORMATO NUMERO DE CONTA */

CREATE OR REPLACE FUNCTION unformat_account_number( account_number varchar )
RETURNS varchar
LANGUAGE 'plpgsql'
AS $$
	BEGIN
		RETURN REPLACE(CAST(account_number AS VARCHAR), '.', '');
	END;
$$;


/* PEGAR LEVEL DA CONTA PELO NUMERO DE CONTA FORMATADO */

CREATE OR REPLACE FUNCTION get_account_level( formated_account_number varchar )
RETURNS smallint
LANGUAGE 'plpgsql'
AS $$
	DECLARE
		counter smallint := 0;
		reversed_acc varchar;
	BEGIN
		reversed_acc := REVERSE(formated_account_number);
		FOR i IN 1..16 LOOP
			IF substring(reversed_acc from i for 1) = '0' THEN
				CONTINUE;
			ELSIF substring(reversed_acc from i for 1) = '.' THEN
				counter = counter + 1;
			ELSE
				EXIT;
			END IF;
		END LOOP;
		RETURN 6 - counter;
	END;
$$;


/* PEGAR COMEÇO DA CONTA SUPERIOR */

CREATE OR REPLACE FUNCTION get_last_account_level( formated_account_number varchar )
RETURNS varchar
LANGUAGE 'plpgsql'
AS $$
	DECLARE
		last_level smallint;
		cleaver smallint;
	BEGIN
		last_level := get_account_level(formated_account_number);
		CASE last_level
			WHEN 2 THEN
				cleaver := 1;
			WHEN 3 THEN
				cleaver := 2;
			WHEN 4 THEN
				cleaver := 4;
			WHEN 5 THEN
				cleaver := 6;
			WHEN 6 THEN
				cleaver := 9;
		END CASE;
		RETURN substring(
			CAST(unformat_account_number(formated_account_number) AS varchar)
			from 1 for cleaver
		);
	END;
$$;
