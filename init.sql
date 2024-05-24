CREATE USER IF NOT EXISTS 'perl_mail_log_parser_db_user'@'localhost' IDENTIFIED BY 'perl_mail_log_parser_db_password';
CREATE DATABASE IF NOT EXISTS perl_mail_log_parser_db;
USE perl_mail_log_parser_db;
GRANT ALL PRIVILEGES ON perl_mail_log_parser_db.* TO 'perl_mail_log_parser_db_user'@'localhost';
CREATE TABLE IF NOT EXISTS message (
    created TIMESTAMP(0) ,
    id varchar(255),
    int_id CHAR(16) ,
    str TEXT ,
    status BOOL
);
CREATE INDEX message_created_idx ON message (created);
CREATE INDEX message_int_id_idx ON message (int_id);
CREATE TABLE IF NOT EXISTS log (
    created TIMESTAMP(0) ,
    int_id CHAR(16) NOT NULL,
    str TEXT,
    address TEXT
);
