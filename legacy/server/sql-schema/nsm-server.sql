


CREATE TABLE `user_info` (
  `uid` int(5) NOT NULL AUTO_INCREMENT,
  `gid` int(5) NOT NULL DEFAULT '0',
  `enabled` enum('N','Y') NOT NULL DEFAULT 'N',
  `login_count` int(15) NOT NULL DEFAULT '0',
  `username`  varchar(16) NOT NULL DEFAULT '',
  `password`  varchar(50) NOT NULL DEFAULT '',
  `firstname` varchar(255) NOT NULL DEFAULT '',
  `lastname`  varchar(255) NOT NULL DEFAULT '',
  `title`     varchar(255) NOT NULL DEFAULT '',
  `company`   varchar(255) NOT NULL DEFAULT '',
  `street`    varchar(255) NOT NULL DEFAULT '',
  `zipcode`   varchar(255) NOT NULL DEFAULT '',
  `city`      varchar(255) NOT NULL DEFAULT '',
  `contry`    varchar(255) NOT NULL DEFAULT '',
  `phone`     varchar(255) NOT NULL DEFAULT '',
  `email`     varchar(255) NOT NULL DEFAULT '',
  `created`         timestamp   NOT NULL default CURRENT_TIMESTAMP,
  `updated`         timestamp   NOT NULL default CURRENT_TIMESTAMP on update CURRENT_TIMESTAMP,
  `erased`          timestamp,
  `lastlogin_succ`  datetime,
  `lastlogin_fail`  datetime,
  `loginfail_count` int(11) unsigned NOT NULL DEFAULT '0',
  PRIMARY KEY (`uid`),
  UNIQUE KEY `username` (`username`),
) ENGINE=MyISAM AUTO_INCREMENT=2 DEFAULT CHARSET=latin1;


CREATE TABLE `node` (
  `nid`          int(10) unsigned NOT NULL AUTO_INCREMENT,
  `nodename`     varchar(255) NOT NULL,
  `host`         varchar(255) NOT NULL,
  `module_type`  varchar(255) NOT NULL,
  `network`      varchar(255) NOT NULL,
  `interface`    varchar(255) NOT NULL,
  `description`  TEXT,
  `bpf_filter`   TEXT,
  `first_seen`   datetime NOT NULL,
  `last_seen`    datetime NOT NULL,
  `ip`           decimal(39,0) unsigned DEFAULT NULL,
  `key`          TEXT,
  PRIMARY KEY (`sid`),
);

CREATE TABLE IF NOT EXISTS `worker` (
  `wid`          int(10) unsigned NOT NULL AUTO_INCREMENT,
  `workername`   varchar(255) NOT NULL,
  `host`         varchar(255) NOT NULL,
  `module_type`  varchar(255) NOT NULL,
  `network`      varchar(255) NOT NULL,
  `description`  TEXT,
  `first_seen`   datetime NOT NULL,
  `last_seen`    datetime NOT NULL,
  `ip`           decimal(39,0) unsigned DEFAULT NULL,
  `key`          TEXT,
  PRIMARY KEY (`sid`),
);

CREATE TABLE IF NOT EXISTS `autocat` (
  `autocatid`   int(14) unsigned       NOT NULL AUTO_INCREMENT,
  `hostname`    varchar(255)           NOT NULL,
  `network`     varchar(255)           NOT NULL,
  `s_ip`        decimal(39,0) unsigned DEFAULT NULL,
  `s_port`      smallint(5) unsigned   DEFAULT NULL,
  `d_ip`        decimal(39,0) unsigned DEFAULT NULL,
  `d_port`      smallint(5) unsigned   DEFAULT NULL,
  `proto`       varchar(30) default    NULL,
  `category`    smallint unsigned      NOT NULL,
  `comment`     TEXT,
  `created`     timestamp   NOT NULL default CURRENT_TIMESTAMP,
  `updated`     timestamp   NOT NULL default CURRENT_TIMESTAMP on update CURRENT_TIMESTAMP,
  `erased`      timestamp,
  PRIMARY KEY  (`autocatid`)
) ENGINE=MyISAM AUTO_INCREMENT=1 DEFAULT CHARSET=latin1;

CREATE TABLE IF NOT EXISTS `prads` (
  `nid`                   int(14) unsigned       NOT NULL,
  `nodename`              varchar(255)           NOT NULL,
  `network`               varchar(255)           NOT NULL,
  `first_seen`            datetime NOT NULL default CURRENT_TIMESTAMP,,
  `last_seen`             datetime NOT NULL default CURRENT_TIMESTAMP on update CURRENT_TIMESTAMP,
  `vlan`                  smallint(4) unsigned   DEFAULT NULL,
  `ip`                    decimal(39,0) unsigned DEFAULT NULL,
  `service`               varchar(20)            NOT NULL,
  `service_info`          varchar(255)           NOT NULL,
  `port`                  smallint(5) unsigned   DEFAULT NULL,
  `ip_proto`              tinyint unsigned       NOT NULL,
  `distance`              smallint(3) unsigned   DEFAULT NULL,
  `application`           varchar(255)           NOT NULL,
  PRIMARY KEY (ip)
);

CREATE TABLE IF NOT EXISTS `version` (
  `version`   varchar(255) NOT NULL,
  `installed` datetime     NOT NULL,
);

INSERT INTO `version` (`version`, `installed`) VALUES ("0.1", now());

CREATE TABLE IF NOT EXISTS `status` (
  `status_id`     SMALLINT UNSIGNED NOT NULL,
  `description`   VARCHAR(255)      NOT NULL,
  `long_desc`     VARCHAR(255),
  PRIMARY KEY (status_id)
);

INSERT INTO `status` (status_id, description, long_desc) VALUES (  0, "Category   0", "Real Time Event");
INSERT INTO `status` (status_id, description, long_desc) VALUES (  1, "Category   1", "Unauthorized Root Access");
INSERT INTO `status` (status_id, description, long_desc) VALUES (  2, "Category   2", "Unauthorized User Access");
INSERT INTO `status` (status_id, description, long_desc) VALUES (  3, "Category   3", "Attempted Unauthorized Access");
INSERT INTO `status` (status_id, description, long_desc) VALUES (  4, "Category   4", "Successful Denial of Service Attack");
INSERT INTO `status` (status_id, description, long_desc) VALUES (  5, "Category   5", "Poor Security Practice or Policy Violation");
INSERT INTO `status` (status_id, description, long_desc) VALUES (  6, "Category   6", "Reconnaissance/Probes/Scans");
INSERT INTO `status` (status_id, description, long_desc) VALUES (  7, "Category   7", "Virus Infection");
INSERT INTO `status` (status_id, description, long_desc) VALUES (  8, "Category   8", "Trojan/Backdoor Detected");
INSERT INTO `status` (status_id, description, long_desc) VALUES (  9, "Category   9", "Bot Detected");
INSERT INTO `status` (status_id, description, long_desc) VALUES ( 90, "Category  90", "No Further Action Required");
INSERT INTO `status` (status_id, description, long_desc) VALUES (100, "Category 100", "Escalated");


