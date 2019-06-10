

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

/* REMOVE FORMATO NUMERO DE CONTA (Transforma diretamente em BIGINT) */

CREATE OR REPLACE FUNCTION unformat_account_number( account_number varchar )
RETURNS bigint
LANGUAGE 'plpgsql'
AS $$
	BEGIN
		RETURN CAST(REPLACE(CAST(account_number AS VARCHAR), '.', '') AS bigint);
	END;
$$;