-- ## USE THIS IF HAVE gotKey AND alarm COLUMNS IN YOU owned_vehicles TABLE ## --

ALTER TABLE player_vehicles CHANGE COLUMN `gotKey` `t1ger_keys` TINYINT(1) NOT NULL DEFAULT 0;
UPDATE player_vehicles SET alarm = 1 WHERE alarm > 0;
ALTER TABLE player_vehicles CHANGE COLUMN alarm t1ger_alarm TINYINT(1) NOT NULL DEFAULT 0;