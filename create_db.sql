USE db;

CREATE TABLE wp_role(
    ID VARCHAR(36) NOT NULL PRIMARY KEY DEFAULT(UUID()),
    role_name VARCHAR(255) NOT NULL UNIQUE
);

CREATE TABLE wp_user(
    ID VARCHAR(36) NOT NULL PRIMARY KEY DEFAULT(UUID()),
    user_login VARCHAR(255) NOT NULL UNIQUE,
    user_salt VARCHAR(255) NOT NULL,
    user_pass VARCHAR(255) NOT NULL,
    user_display_name VARCHAR(255) NOT NULL,
    -- user_phone VARCHAR(16) NOT NULL UNIQUE,
    user_registered BIGINT NOT NULL DEFAULT(UNIX_TIMESTAMP()),

    role_id VARCHAR(36) NOT NULL,
    FOREIGN KEY (role_id) REFERENCES wp_role (ID)
	
	-- CONSTRAINT CH_phone CHECK(user_phone REGEXP '[0-9]{10,16}')
);

CREATE TABLE wp_usermeta(
    ID VARCHAR(36) NOT NULL PRIMARY KEY DEFAULT(UUID()),
    user_meta_key VARCHAR(255) NULL,
    user_meta_value VARCHAR(255) NULL,

    user_id VARCHAR(36) NOT NULL,
    FOREIGN KEY (user_id) REFERENCES wp_user (ID)
);

CREATE TABLE wp_place(
	ID VARCHAR(36) NOT NULL PRIMARY KEY DEFAULT(UUID()),
	place_is_valid BIT NOT NULL DEFAULT(1),
	place_code VARCHAR(4) NOT NULL UNIQUE,
	
	CONSTRAINT CH_code_place CHECK(place_code REGEXP '[A-Z][0-9][0-9][0-9]')
);

CREATE TABLE wp_message(
    ID VARCHAR(36) NOT NULL PRIMARY KEY DEFAULT(UUID()),
    message_text TEXT NULL,
    message_date BIGINT NULL DEFAULT(UNIX_TIMESTAMP()),
    message_iterate BIGINT NOT NULL DEFAULT(0),
    message_is_end BIT NOT NULL DEFAULT(0),

	message_bot_chat_telegram_id BIGINT NULL,
	message_bot_telegram_id BIGINT NULL,
	message_chat_telegram_id BIGINT NULL,
    message_telegram_id BIGINT NULL,

    user_id VARCHAR(36) NULL,
    message_root_id VARCHAR(36) NULL,
    message_answer_id VARCHAR(36) NULL,
    FOREIGN KEY (user_id) REFERENCES wp_user (ID),
    FOREIGN KEY (message_root_id) REFERENCES wp_message(ID),
    FOREIGN KEY (message_answer_id) REFERENCES wp_message(ID)
);

CREATE TABLE wp_document(
    ID VARCHAR(36) NOT NULL PRIMARY KEY DEFAULT(UUID()),
    document_file_id VARCHAR(100),
    document_file_unique_id VARCHAR(100),
    document_file_size BIGINT,
    document_file_url  TEXT,
    document_file_mime TEXT,

    message_id VARCHAR(36) NOT NULL,
    FOREIGN KEY (message_id) REFERENCES wp_message(ID)
);

CREATE TABLE wp_reserve(
	ID VARCHAR(36) NOT NULL PRIMARY KEY DEFAULT(UUID()),
	reserve_begin BIGINT NOT NULL,
	reserve_end BIGINT NOT NULL,
	reserve_state INT NOT NULL,
    
    reserve_create BIGINT NOT NULL DEFAULT(UNIX_TIMESTAMP()),

	place_id VARCHAR(36) NULL,
	user_id VARCHAR(36) NOT NULL,
	FOREIGN KEY(place_id) REFERENCES wp_place(ID),
	FOREIGN KEY(user_id) REFERENCES wp_user(ID),
	
	CONSTRAINT CH_timestamp_reserve CHECK(reserve_begin < reserve_end),
	CONSTRAINT CH_state_reserve CHECK(reserve_state >= 1 AND reserve_state <= 4)
);

CREATE TABLE wp_auth_history(
	ID VARCHAR(36) NOT NULL PRIMARY KEY DEFAULT(UUID()),
	auth_date INT NOT NULL,

	user_id VARCHAR(36) NOT NULL,
	FOREIGN KEY(user_id) REFERENCES wp_user(ID)
);

CREATE TABLE wp_token_bloclist(
    ID VARCHAR(36) NOT NULL PRIMARY KEY DEFAULT(UUID()),
	token_jti VARCHAR(255) NOT NULL,
	token_create BIGINT NOT NULL DEFAULT(UNIX_TIMESTAMP())
);

CREATE TABLE wp_reserve_history(
	ID VARCHAR(36) NOT NULL PRIMARY KEY DEFAULT(UUID()),
	reserve_id VARCHAR(36) NOT NULL,
	reserve_state INT NOT NULL
);

INSERT INTO wp_role(role_name)
VALUES ("ADMIN"), ("EMPLOYEE"), ("USER");

INSERT INTO wp_user (user_login, user_salt, user_pass, user_display_name, role_id)
VALUES ('user1', 'bdc791ef173fc8cf9eb7dd377acf6a11', '805b194450d4c4da4d11d1954aca21fbc756e79f45d41f450de1ae644cd08e91', 'User One', (SELECT ID FROM wp_role WHERE role_name = 'ADMIN')), 
       ('user2', 'b1f83394319c815bc4df0d4bd3211bdd', '7c37613dc17dfd8a45c73b0afee3be0553c3da7f7449e3b250cf3eec74e412dd', 'User Two', (SELECT ID FROM wp_role WHERE role_name = 'EMPLOYEE')), 
       ('user3', '710cdfa5e5bf91b393d64d16fa6d6881', '4311a3f1af29db53f5cf7bd4b175b22cd3e69ad8419d1b198c2e24e80f17f6c8', 'User Three', (SELECT ID FROM wp_role WHERE role_name = 'USER'));


INSERT into wp_place (place_code)
SELECT CONCAT(CHAR(let_code._code USING utf8mb4), num.num)
FROM 
	(
		SELECT Concat(a.num, b.num, c.num) AS num FROM
			(SELECT 0 AS num UNION ALL SELECT 1 UNION ALL SELECT 2 UNION ALL SELECT 3 UNION ALL SELECT 4 UNION ALL SELECT 5 UNION ALL SELECT 6 UNION ALL SELECT 7 UNION ALL SELECT 8 UNION ALL SELECT 9) AS a,
			(SELECT 0 AS num UNION ALL SELECT 1 UNION ALL SELECT 2 UNION ALL SELECT 3 UNION ALL SELECT 4 UNION ALL SELECT 5 UNION ALL SELECT 6 UNION ALL SELECT 7 UNION ALL SELECT 8 UNION ALL SELECT 9) AS b,
			(SELECT 0 AS num UNION ALL SELECT 1 UNION ALL SELECT 2 UNION ALL SELECT 3 UNION ALL SELECT 4 UNION ALL SELECT 5 UNION ALL SELECT 6 UNION ALL SELECT 7 UNION ALL SELECT 8 UNION ALL SELECT 9) AS c
		Where (a.num * 100 + b.num * 10 + c.num) < 25
        ORDER BY num
	) AS num,
	(
		SELECT (a.digit * 10 + b.digit) AS _code FROM
			(SELECT 6 AS digit UNION ALL SELECT 7 UNION ALL SELECT 8 UNION ALL SELECT 9) AS a,
			(SELECT 0 AS digit UNION ALL SELECT 1 UNION ALL SELECT 2 UNION ALL SELECT 3 UNION ALL SELECT 4 UNION ALL SELECT 5 UNION ALL SELECT 6 UNION ALL SELECT 7 UNION ALL SELECT 8 UNION ALL SELECT 9) AS b
		WHERE (a.digit * 10 + b.digit) <= 90 && (a.digit * 10 + b.digit) >= 65
        ORDER BY _code
	) let_code
ORDER BY let_code._code, num.num;


DELIMITER //
CREATE TRIGGER reserve_insert_check
AFTER INSERT ON wp_reserve
FOR EACH ROW
BEGIN
    INSERT INTO wp_reserve_history (reserve_id, reserve_state)
    VALUES (NEW.ID, NEW.reserve_state);
END//

CREATE TRIGGER reserve_update_check
BEFORE UPDATE ON wp_reserve
FOR EACH ROW
BEGIN
    -- IF EXISTS(SELECT * FROM wp_reserve_history WHERE reserve_id = NEW.ID AND reserve_state = 1) THEN
    --     SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Rerserve deleted!';
    -- END IF;

	-- IF NOT EXISTS (SELECT * from wp_reserve WHERE (
    --     (NEW.reserve_begin BETWEEN reserve_begin AND reserve_end) OR 
    --     (NEW.reserve_end BETWEEN reserve_begin AND reserve_end)) AND 
    --     (place_id = NEW.place_id)) THEN
    --     SIGNAL SQLSTATE '45001' SET MESSAGE_TEXT = 'Пересечение диапазонов дат недопустимо!';
    -- END IF;
    UPDATE wp_reserve_history SET reserve_state = NEW.reserve_state WHERE reserve_id = NEW.ID;
    
END//

DELIMITER ;