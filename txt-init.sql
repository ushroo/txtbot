----------------------------------------------------------------------------------------------------
--
-- txt-init.sql
--
----------------------------------------------------------------------------------------------------

\c template1

DROP    DATABASE IF EXISTS txt;
CREATE  DATABASE           txt ENCODING 'UTF-8';

\c txt;

-- make tables -------------------------------------------------------------------------------------

CREATE TABLE users (
    id                  SERIAL      NOT NULL UNIQUE,

    name                VARCHAR     NOT NULL UNIQUE,
    pnum                VARCHAR     NOT NULL UNIQUE,

    PRIMARY KEY ( id )
    );

INSERT INTO users ( name, pnum ) VALUES ( '...',   '+..........' );

CREATE TABLE txts (
    id                  SERIAL      NOT NULL UNIQUE,

    tw_Time             INTEGER     NOT NULL,
    tw_Body             VARCHAR     NOT NULL,
    tw_From             VARCHAR     NOT NULL,
    tw_FromCity         VARCHAR     NOT NULL,
    tw_FromCountry      VARCHAR     NOT NULL,
    tw_FromState        VARCHAR     NOT NULL,
    tw_FromZip          VARCHAR     NOT NULL,
    tw_MessageSid       VARCHAR     NOT NULL UNIQUE,
    tw_NumMedia         VARCHAR     NOT NULL,
    tw_SmsMessageSid    VARCHAR     NOT NULL,
    tw_SmsSid           VARCHAR     NOT NULL,
    tw_SmsStatus        VARCHAR     NOT NULL,
    tw_To               VARCHAR     NOT NULL,
    tw_ToCity           VARCHAR     NOT NULL,
    tw_ToCountry        VARCHAR     NOT NULL,
    tw_ToState          VARCHAR     NOT NULL,
    tw_ToZip            VARCHAR     NOT NULL,

    PRIMARY KEY ( id )
    );

--   MediaContentType0 - image/jpeg
--   MediaUrl0 - https://api.twilio.com/ME...

CREATE TABLE media (
    id                  SERIAL      NOT NULL UNIQUE,

    tw_MessageSid       VARCHAR     NOT NULL REFERENCES txts ( tw_MessageSid ),

    idx                 INTEGER     NOT NULL,
    status              INTEGER     NOT NULL DEFAULT 0,
    filename            VARCHAR     NOT NULL,

    tw_MediaContentType VARCHAR     NOT NULL,   -- image/jpeg
    tw_MediaUrl         VARCHAR     NOT NULL,   -- ABCDEFGH.jpg

    PRIMARY KEY ( id ),
    UNIQUE ( tw_MessageSid, idx )
    );

-- nicer viewers

CREATE VIEW nice_txts  AS SELECT id, tw_time, tw_from, tw_messagesid, tw_body FROM txts ORDER BY id DESC;
CREATE VIEW nice_media AS SELECT id, tw_messagesid, idx, status, filename, tw_mediacontenttype FROM media ORDER BY id DESC;

----------------------------------------------------------------------------------------------------

REVOKE ALL PRIVILEGES ON DATABASE txt    FROM public;
REVOKE ALL PRIVILEGES ON SCHEMA   public FROM txt;
REVOKE ALL PRIVILEGES ON SCHEMA   public FROM public;

DROP   ROLE IF EXISTS txt;
CREATE ROLE           txt LOGIN PASSWORD 'txt' NOSUPERUSER NOINHERIT
                          NOCREATEDB NOCREATEROLE CONNECTION LIMIT 15;

GRANT CONNECT ON DATABASE txt    TO txt;
GRANT USAGE   ON SCHEMA   public TO txt;

GRANT select, insert, update, delete
    ON TABLE users, txts, media
    TO txt;

GRANT update
    ON SEQUENCE users_id_seq, txts_id_seq, media_id_seq
    TO txt;

----------------------------------------------------------------------------------------------------
