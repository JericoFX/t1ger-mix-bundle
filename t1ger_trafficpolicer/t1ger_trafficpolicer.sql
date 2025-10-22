DROP TABLE IF EXISTS `t1ger_anpr`;
CREATE TABLE `t1ger_anpr`  (
        `citizenid` varchar(50) NOT NULL,
        `plate` varchar(12) NOT NULL,
        `owner` varchar(255) NOT NULL,
        `stolen` tinyint(1) NOT NULL DEFAULT 0,
        `bolo` tinyint(1) NOT NULL DEFAULT 0,
        `insurance` tinyint(1) NOT NULL DEFAULT 0,
        PRIMARY KEY (`plate`)
);

DROP TABLE IF EXISTS `t1ger_citations`;
CREATE TABLE `t1ger_citations`  (
        `id` int AUTO_INCREMENT,
        `officer_cid` varchar(50) NOT NULL,
        `offender_cid` varchar(50) NOT NULL,
        `fine` int(12) NOT NULL,
        `offences` LONGTEXT NOT NULL,
        `note` varchar(255) DEFAULT NULL,
        `paid` tinyint(1) NOT NULL DEFAULT 0,
        `signature` varchar(64) NOT NULL,
        `issued_at` bigint NOT NULL,
        PRIMARY KEY (`id`),
        KEY `signature` (`signature`)
);
ALTER TABLE `t1ger_citations` AUTO_INCREMENT = 1000;
