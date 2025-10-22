DROP TABLE IF EXISTS `t1ger_deliveries`;
CREATE TABLE IF NOT EXISTS `t1ger_deliveries` (
    `id` INT NOT NULL,
    `citizenid` VARCHAR(50) NOT NULL,
    `name` VARCHAR(100) NOT NULL,
    `level` INT NOT NULL DEFAULT 0,
    `certificate` TINYINT(1) NOT NULL DEFAULT 0,
    PRIMARY KEY (`id`)
);
