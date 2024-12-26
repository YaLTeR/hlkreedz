-- MySQL dump 10.13  Distrib 8.0.15-5, for debian-linux-gnu (x86_64)
--
-- Host: localhost    Database: hlkz1
-- ------------------------------------------------------
-- Server version	8.0.15-5

/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
 SET NAMES utf8mb4 ;
/*!40103 SET @OLD_TIME_ZONE=@@TIME_ZONE */;
/*!40103 SET TIME_ZONE='+00:00' */;
/*!40014 SET @OLD_UNIQUE_CHECKS=@@UNIQUE_CHECKS, UNIQUE_CHECKS=0 */;
/*!40014 SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0 */;
/*!40101 SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='NO_AUTO_VALUE_ON_ZERO' */;
/*!40111 SET @OLD_SQL_NOTES=@@SQL_NOTES, SQL_NOTES=0 */;
/*!50717 SELECT COUNT(*) INTO @rocksdb_has_p_s_session_variables FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = 'performance_schema' AND TABLE_NAME = 'session_variables' */;
/*!50717 SET @rocksdb_get_is_supported = IF (@rocksdb_has_p_s_session_variables, 'SELECT COUNT(*) INTO @rocksdb_is_supported FROM performance_schema.session_variables WHERE VARIABLE_NAME=\'rocksdb_bulk_load\'', 'SELECT 0') */;
/*!50717 PREPARE s FROM @rocksdb_get_is_supported */;
/*!50717 EXECUTE s */;
/*!50717 DEALLOCATE PREPARE s */;
/*!50717 SET @rocksdb_enable_bulk_load = IF (@rocksdb_is_supported, 'SET SESSION rocksdb_bulk_load = 1', 'SET @rocksdb_dummy_bulk_load = 0') */;
/*!50717 PREPARE s FROM @rocksdb_enable_bulk_load */;
/*!50717 EXECUTE s */;
/*!50717 DEALLOCATE PREPARE s */;
SET @MYSQLDUMP_TEMP_LOG_BIN = @@SESSION.SQL_LOG_BIN;
SET @@SESSION.SQL_LOG_BIN= 0;

--
-- GTID state at the beginning of the backup 
--

SET @@GLOBAL.GTID_PURGED=/*!80000 '+'*/ '41745d36-55d1-11e9-a15d-f23c91a5b2ee:1-7136755';

--
-- Temporary view structure for view `DataForMedalsView`
--

DROP TABLE IF EXISTS `DataForMedalsView`;
/*!50001 DROP VIEW IF EXISTS `DataForMedalsView`*/;
SET @saved_cs_client     = @@character_set_client;
SET character_set_client = utf8mb4;
/*!50001 CREATE VIEW `DataForMedalsView` AS SELECT 
 1 AS `Map name`,
 1 AS `WR time`,
 1 AS `Best 5% runs avg. time`,
 1 AS `Top 15 avg. time`,
 1 AS `#10 time`,
 1 AS `Mid time`,
 1 AS `Avg. time`,
 1 AS `Total time`,
 1 AS `Runs`,
 1 AS `Runners`*/;
SET character_set_client = @saved_cs_client;

--
-- Temporary view structure for view `SeasonMapPool`
--

DROP TABLE IF EXISTS `SeasonMapPool`;
/*!50001 DROP VIEW IF EXISTS `SeasonMapPool`*/;
SET @saved_cs_client     = @@character_set_client;
SET character_set_client = utf8mb4;
/*!50001 CREATE VIEW `SeasonMapPool` AS SELECT 
 1 AS `Map name`,
 1 AS `WR time`,
 1 AS `Best 5% runs avg. time`,
 1 AS `Top 15 avg. time`,
 1 AS `#10 time`,
 1 AS `Mid time`,
 1 AS `Avg. time`,
 1 AS `Total time`,
 1 AS `Runs`,
 1 AS `Runners`*/;
SET character_set_client = @saved_cs_client;

--
-- Temporary view structure for view `SeasonMapPoolExtended`
--

DROP TABLE IF EXISTS `SeasonMapPoolExtended`;
/*!50001 DROP VIEW IF EXISTS `SeasonMapPoolExtended`*/;
SET @saved_cs_client     = @@character_set_client;
SET character_set_client = utf8mb4;
/*!50001 CREATE VIEW `SeasonMapPoolExtended` AS SELECT 
 1 AS `Map name`,
 1 AS `WR time`,
 1 AS `Best 5% runs avg. time`,
 1 AS `Top 15 avg. time`,
 1 AS `#10 time`,
 1 AS `Mid time`,
 1 AS `Avg. time`,
 1 AS `Total time`,
 1 AS `Runs`,
 1 AS `Runners`*/;
SET character_set_client = @saved_cs_client;

--
-- Temporary view structure for view `SeasonMapPoolTrendy`
--

DROP TABLE IF EXISTS `SeasonMapPoolTrendy`;
/*!50001 DROP VIEW IF EXISTS `SeasonMapPoolTrendy`*/;
SET @saved_cs_client     = @@character_set_client;
SET character_set_client = utf8mb4;
/*!50001 CREATE VIEW `SeasonMapPoolTrendy` AS SELECT 
 1 AS `Map name`,
 1 AS `Best time`,
 1 AS `Best 5% runs avg. time`,
 1 AS `Top 15 avg. time`,
 1 AS `#10 time`,
 1 AS `Mid time`,
 1 AS `Avg. time`,
 1 AS `Total time`,
 1 AS `Runs`,
 1 AS `Runners`*/;
SET character_set_client = @saved_cs_client;

--
-- Temporary view structure for view `SeasonMapPoolTrendyExtended`
--

DROP TABLE IF EXISTS `SeasonMapPoolTrendyExtended`;
/*!50001 DROP VIEW IF EXISTS `SeasonMapPoolTrendyExtended`*/;
SET @saved_cs_client     = @@character_set_client;
SET character_set_client = utf8mb4;
/*!50001 CREATE VIEW `SeasonMapPoolTrendyExtended` AS SELECT 
 1 AS `Map name`,
 1 AS `Best time`,
 1 AS `Best 5% runs avg. time`,
 1 AS `Top 15 avg. time`,
 1 AS `#10 time`,
 1 AS `Mid time`,
 1 AS `Avg. time`,
 1 AS `Total time`,
 1 AS `Runs`,
 1 AS `Runners`*/;
SET character_set_client = @saved_cs_client;

--
-- Table structure for table `audit`
--

DROP TABLE IF EXISTS `audit`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
 SET character_set_client = utf8mb4 ;
CREATE TABLE `audit` (
  `id` mediumint(8) unsigned NOT NULL AUTO_INCREMENT,
  `action` enum('INSERT','UPDATE','DELETE','') COLLATE utf8_unicode_ci NOT NULL,
  `date` timestamp NOT NULL,
  `data_manipulator` tinyint(3) unsigned NOT NULL,
  `table_name` varchar(32) COLLATE utf8_unicode_ci NOT NULL,
  `row_id` int(10) unsigned NOT NULL,
  `column_name` varchar(32) COLLATE utf8_unicode_ci DEFAULT NULL,
  `field_old_value` varchar(100) COLLATE utf8_unicode_ci DEFAULT NULL,
  `field_new_value` varchar(100) COLLATE utf8_unicode_ci DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `banned_map`
--

DROP TABLE IF EXISTS `banned_map`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
 SET character_set_client = utf8mb4 ;
CREATE TABLE `banned_map` (
  `id` mediumint(8) unsigned NOT NULL AUTO_INCREMENT,
  `hlkz_match` mediumint(8) unsigned NOT NULL,
  `map` smallint(5) unsigned NOT NULL,
  `player` smallint(5) unsigned NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `UNIQUE_HLKZ_MATCH_MAP` (`hlkz_match`,`map`) USING BTREE,
  KEY `player` (`player`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `checkpoint`
--

DROP TABLE IF EXISTS `checkpoint`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
 SET character_set_client = utf8mb4 ;
CREATE TABLE `checkpoint` (
  `id` mediumint(8) unsigned NOT NULL AUTO_INCREMENT,
  `name` varchar(64) COLLATE utf8_unicode_ci NOT NULL,
  `player` smallint(5) unsigned NOT NULL,
  `type` tinyint(3) unsigned NOT NULL COMMENT 'Corresponding to CP_TYPES enum in HLKZ source code',
  `visibility` tinyint(3) unsigned NOT NULL COMMENT 'none, private, public',
  `times_used` mediumint(8) unsigned NOT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `city`
--

DROP TABLE IF EXISTS `city`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
 SET character_set_client = utf8mb4 ;
CREATE TABLE `city` (
  `id` smallint(5) unsigned NOT NULL AUTO_INCREMENT,
  `name` varchar(32) COLLATE utf8_unicode_ci NOT NULL,
  `country` tinyint(3) unsigned NOT NULL,
  `timezone` varchar(32) COLLATE utf8_unicode_ci NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `UNIQUE_NAME` (`name`),
  KEY `country` (`country`)
) ENGINE=InnoDB AUTO_INCREMENT=8 DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `competition`
--

DROP TABLE IF EXISTS `competition`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
 SET character_set_client = utf8mb4 ;
CREATE TABLE `competition` (
  `id` smallint(5) unsigned NOT NULL AUTO_INCREMENT,
  `name` varchar(50) COLLATE utf8_unicode_ci NOT NULL,
  `size` smallint(5) unsigned NOT NULL,
  `creator` smallint(5) unsigned NOT NULL,
  `creation_date` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `start_date` timestamp NULL DEFAULT NULL,
  `end_date` timestamp NULL DEFAULT NULL,
  `type` varchar(32) COLLATE utf8_unicode_ci NOT NULL,
  `is_official` tinyint(1) NOT NULL,
  PRIMARY KEY (`id`),
  KEY `creator` (`creator`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `competition_map_pool`
--

DROP TABLE IF EXISTS `competition_map_pool`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
 SET character_set_client = utf8mb4 ;
CREATE TABLE `competition_map_pool` (
  `id` mediumint(8) unsigned NOT NULL AUTO_INCREMENT,
  `competition` smallint(5) unsigned NOT NULL,
  `map` smallint(5) unsigned NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `UNIQUE_COMPETITION_MAP` (`competition`,`map`) USING BTREE
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `continent`
--

DROP TABLE IF EXISTS `continent`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
 SET character_set_client = utf8mb4 ;
CREATE TABLE `continent` (
  `id` tinyint(3) unsigned NOT NULL AUTO_INCREMENT,
  `name` varchar(32) COLLATE utf8_unicode_ci NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `UNIQUE_NAME` (`name`)
) ENGINE=InnoDB AUTO_INCREMENT=4 DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `country`
--

DROP TABLE IF EXISTS `country`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
 SET character_set_client = utf8mb4 ;
CREATE TABLE `country` (
  `id` tinyint(3) unsigned NOT NULL AUTO_INCREMENT,
  `name` varchar(64) COLLATE utf8_unicode_ci NOT NULL,
  `code` char(2) COLLATE utf8_unicode_ci NOT NULL,
  `flag` varchar(255) CHARACTER SET utf8 COLLATE utf8_unicode_ci DEFAULT NULL,
  `continent` tinyint(3) unsigned NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `UNIQUE_NAME` (`name`),
  UNIQUE KEY `UNIQUE_CODE` (`code`),
  KEY `continent` (`continent`)
) ENGINE=InnoDB AUTO_INCREMENT=8 DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `data_manipulator`
--

DROP TABLE IF EXISTS `data_manipulator`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
 SET character_set_client = utf8mb4 ;
CREATE TABLE `data_manipulator` (
  `id` tinyint(3) unsigned NOT NULL AUTO_INCREMENT,
  `player` smallint(5) unsigned DEFAULT NULL,
  `web_user` varchar(32) COLLATE utf8_unicode_ci DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `player` (`player`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `difficulty`
--

DROP TABLE IF EXISTS `difficulty`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
 SET character_set_client = utf8mb4 ;
CREATE TABLE `difficulty` (
  `id` tinyint(3) unsigned NOT NULL,
  `name` varchar(32) COLLATE utf8_unicode_ci NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `UNIQUE_NAME` (`name`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `failed_attempt`
--

DROP TABLE IF EXISTS `failed_attempt`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
 SET character_set_client = utf8mb4 ;
CREATE TABLE `failed_attempt` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `player` smallint(5) unsigned NOT NULL,
  `map` smallint(5) unsigned NOT NULL,
  `type` varchar(32) CHARACTER SET utf8 COLLATE utf8_unicode_ci NOT NULL,
  `time` decimal(12,6) NOT NULL,
  `date` timestamp NOT NULL,
  `fail_x` decimal(12,6) DEFAULT NULL,
  `fail_y` decimal(12,6) DEFAULT NULL,
  `fail_z` decimal(12,6) DEFAULT NULL,
  `fps` decimal(8,4) DEFAULT NULL,
  `avg_speed` decimal(11,2) DEFAULT NULL,
  `max_speed` decimal(11,2) DEFAULT NULL,
  `pre_speed` decimal(11,2) DEFAULT NULL,
  `pre_time` decimal(10,6) DEFAULT NULL,
  `timeloss_start` decimal(10,6) DEFAULT NULL,
  `ground_time` decimal(10,6) DEFAULT NULL,
  `ground_distance` decimal(13,4) DEFAULT NULL,
  `distance_2d` decimal(11,2) DEFAULT NULL,
  `distance_3d` decimal(11,2) DEFAULT NULL,
  `sync` decimal(10,6) DEFAULT NULL,
  `speedgain` decimal(10,6) DEFAULT NULL,
  `jumps` mediumint(8) unsigned DEFAULT NULL,
  `ducktaps` mediumint(8) unsigned DEFAULT NULL,
  `slowdowns` mediumint(8) unsigned DEFAULT NULL,
  `hlkz_version` smallint(5) unsigned DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `map` (`map`),
  KEY `player` (`player`),
  KEY `date` (`date`),
  KEY `type` (`type`),
  KEY `time` (`time`),
  KEY `hlkz_version` (`hlkz_version`),
  CONSTRAINT `fk_attempt_hlkz_version` FOREIGN KEY (`hlkz_version`) REFERENCES `hlkz_version` (`id`) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT `fk_attempt_map` FOREIGN KEY (`map`) REFERENCES `map` (`id`) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT `fk_attempt_player` FOREIGN KEY (`player`) REFERENCES `player` (`id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB AUTO_INCREMENT=5255016 DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `game_mod`
--

DROP TABLE IF EXISTS `game_mod`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
 SET character_set_client = utf8mb4 ;
CREATE TABLE `game_mod` (
  `id` tinyint(3) unsigned NOT NULL AUTO_INCREMENT,
  `gamedir` varchar(32) CHARACTER SET utf8 COLLATE utf8_unicode_ci NOT NULL,
  `name` varchar(64) COLLATE utf8_unicode_ci NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `UNIQUE_NAME` (`gamedir`)
) ENGINE=InnoDB AUTO_INCREMENT=3 DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `hlkz_match`
--

DROP TABLE IF EXISTS `hlkz_match`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
 SET character_set_client = utf8mb4 ;
CREATE TABLE `hlkz_match` (
  `id` mediumint(8) unsigned NOT NULL AUTO_INCREMENT,
  `scheduled_date` timestamp NULL DEFAULT NULL,
  `start_date` timestamp NULL DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `hlkz_match_map`
--

DROP TABLE IF EXISTS `hlkz_match_map`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
 SET character_set_client = utf8mb4 ;
CREATE TABLE `hlkz_match_map` (
  `id` mediumint(8) unsigned NOT NULL AUTO_INCREMENT,
  `hlkz_match` mediumint(8) unsigned NOT NULL,
  `map` smallint(5) unsigned NOT NULL,
  PRIMARY KEY (`id`),
  KEY `hlkz_match` (`hlkz_match`),
  KEY `map` (`map`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `hlkz_match_run`
--

DROP TABLE IF EXISTS `hlkz_match_run`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
 SET character_set_client = utf8mb4 ;
CREATE TABLE `hlkz_match_run` (
  `id` mediumint(8) unsigned NOT NULL AUTO_INCREMENT,
  `hlkz_match_map` mediumint(8) unsigned NOT NULL,
  `run` mediumint(8) unsigned NOT NULL,
  `player` smallint(5) unsigned NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `UNIQUE_HLKZ_MATCH_MAP_RUN` (`hlkz_match_map`,`run`) USING BTREE,
  KEY `player` (`player`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `hlkz_version`
--

DROP TABLE IF EXISTS `hlkz_version`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
 SET character_set_client = utf8mb4 ;
CREATE TABLE `hlkz_version` (
  `id` smallint(5) unsigned NOT NULL AUTO_INCREMENT,
  `name` varchar(32) COLLATE utf8_unicode_ci NOT NULL,
  `date_added` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `UNIQUE_NAME` (`name`)
) ENGINE=InnoDB AUTO_INCREMENT=8 DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `issue`
--

DROP TABLE IF EXISTS `issue`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
 SET character_set_client = utf8mb4 ;
CREATE TABLE `issue` (
  `id` smallint(5) unsigned NOT NULL AUTO_INCREMENT,
  `author` smallint(5) unsigned NOT NULL,
  `title` varchar(50) COLLATE utf8_unicode_ci NOT NULL,
  `description` varchar(255) COLLATE utf8_unicode_ci NOT NULL,
  `server` tinyint(3) unsigned NOT NULL,
  `hlkz_version` smallint(5) unsigned NOT NULL,
  PRIMARY KEY (`id`),
  KEY `author` (`author`),
  KEY `server` (`server`),
  KEY `hlkz_version` (`hlkz_version`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `lap_run`
--

DROP TABLE IF EXISTS `lap_run`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
 SET character_set_client = utf8mb4 ;
CREATE TABLE `lap_run` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `run` mediumint(8) unsigned DEFAULT NULL,
  `player` smallint(5) unsigned NOT NULL,
  `map` smallint(5) unsigned NOT NULL,
  `type` varchar(32) CHARACTER SET utf8 COLLATE utf8_unicode_ci NOT NULL,
  `is_no_reset` tinyint(1) NOT NULL DEFAULT '0',
  `lap` smallint(5) unsigned NOT NULL,
  `time` decimal(12,6) NOT NULL,
  `date` timestamp NOT NULL,
  `is_valid` tinyint(1) NOT NULL DEFAULT '1',
  `fps` decimal(8,4) DEFAULT NULL,
  `avg_speed` decimal(8,2) DEFAULT NULL,
  `end_speed` decimal(8,2) DEFAULT NULL,
  `max_speed` decimal(8,2) DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `UNIQUE_LAP` (`lap`,`player`,`map`,`type`,`date`),
  KEY `lap` (`lap`),
  KEY `player` (`player`),
  KEY `map` (`map`),
  KEY `date` (`date`),
  KEY `type` (`type`),
  KEY `run` (`run`),
  CONSTRAINT `fk_lap_run_map` FOREIGN KEY (`map`) REFERENCES `map` (`id`) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT `fk_lap_run_player` FOREIGN KEY (`player`) REFERENCES `player` (`id`) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT `fk_lap_run_run` FOREIGN KEY (`run`) REFERENCES `run` (`id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB AUTO_INCREMENT=25494 DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci ROW_FORMAT=COMPACT;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `map`
--

DROP TABLE IF EXISTS `map`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
 SET character_set_client = utf8mb4 ;
CREATE TABLE `map` (
  `id` smallint(5) unsigned NOT NULL AUTO_INCREMENT,
  `name` varchar(64) COLLATE utf8_unicode_ci NOT NULL,
  `finishing_difficulty` tinyint(3) unsigned NOT NULL DEFAULT '50' COMMENT 'How difficult is it to make a record in this map, be it bad or good, just how hard it''s to reach the end button one way or another',
  `mastering_difficulty` tinyint(3) unsigned NOT NULL DEFAULT '50' COMMENT 'How difficult is it to master this map, to make an almost perfect run',
  `default_start_x` decimal(10,4) DEFAULT NULL,
  `default_start_y` decimal(10,4) DEFAULT NULL,
  `default_start_z` decimal(10,4) DEFAULT NULL,
  `is_deprecated` tinyint(1) NOT NULL DEFAULT '0',
  PRIMARY KEY (`id`),
  UNIQUE KEY `UNIQUE_NAME` (`name`),
  KEY `mastering_difficulty` (`mastering_difficulty`),
  KEY `finishing_difficulty` (`finishing_difficulty`)
) ENGINE=InnoDB AUTO_INCREMENT=6166 DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `map_category`
--

DROP TABLE IF EXISTS `map_category`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
 SET character_set_client = utf8mb4 ;
CREATE TABLE `map_category` (
  `id` tinyint(3) unsigned NOT NULL AUTO_INCREMENT,
  `name` varchar(32) COLLATE utf8_unicode_ci NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `UNIQUE_NAME` (`name`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `map_rating`
--

DROP TABLE IF EXISTS `map_rating`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
 SET character_set_client = utf8mb4 ;
CREATE TABLE `map_rating` (
  `id` mediumint(8) unsigned NOT NULL AUTO_INCREMENT,
  `map` smallint(5) unsigned NOT NULL,
  `player` smallint(5) unsigned NOT NULL,
  `score` decimal(4,2) NOT NULL,
  `date` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `map` (`map`),
  KEY `player` (`player`),
  CONSTRAINT `fk_rating_map` FOREIGN KEY (`map`) REFERENCES `map` (`id`) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT `fk_rating_player` FOREIGN KEY (`player`) REFERENCES `player` (`id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB AUTO_INCREMENT=823 DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `map_subscription`
--

DROP TABLE IF EXISTS `map_subscription`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
 SET character_set_client = utf8mb4 ;
CREATE TABLE `map_subscription` (
  `id` smallint(5) unsigned NOT NULL AUTO_INCREMENT,
  `steamId64` varchar(32) CHARACTER SET utf8 COLLATE utf8_unicode_ci NOT NULL,
  `map` smallint(5) unsigned NOT NULL,
  PRIMARY KEY (`id`),
  KEY `map_subscription_ibfk_1` (`map`),
  KEY `map_subscription_ibfk_2` (`steamId64`),
  CONSTRAINT `map_subscription_ibfk_1` FOREIGN KEY (`map`) REFERENCES `map` (`id`) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT `map_subscription_ibfk_2` FOREIGN KEY (`steamId64`) REFERENCES `profile` (`steamId64`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB AUTO_INCREMENT=24 DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `map_type`
--

DROP TABLE IF EXISTS `map_type`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
 SET character_set_client = utf8mb4 ;
CREATE TABLE `map_type` (
  `id` mediumint(8) unsigned NOT NULL,
  `map` smallint(5) unsigned NOT NULL,
  `category` tinyint(3) unsigned NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `UNIQUE_MAP` (`map`,`category`) USING BTREE
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `mission`
--

DROP TABLE IF EXISTS `mission`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
 SET character_set_client = utf8mb4 ;
CREATE TABLE `mission` (
  `id` smallint(5) unsigned NOT NULL AUTO_INCREMENT,
  `name` varchar(100) COLLATE utf8_unicode_ci NOT NULL,
  `factor` decimal(8,4) NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `UNIQUE_NAME` (`name`) USING BTREE
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `player`
--

DROP TABLE IF EXISTS `player`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
 SET character_set_client = utf8mb4 ;
CREATE TABLE `player` (
  `id` smallint(5) unsigned NOT NULL AUTO_INCREMENT,
  `unique_id` varchar(32) CHARACTER SET utf8 COLLATE utf8_unicode_ci DEFAULT NULL,
  `realname` varchar(32) CHARACTER SET utf8 COLLATE utf8_unicode_ci DEFAULT NULL,
  `rank` tinyint(3) unsigned NOT NULL DEFAULT '32',
  `title` varchar(100) CHARACTER SET utf8 COLLATE utf8_unicode_ci DEFAULT NULL,
  `has_given_storage_consent` tinyint(1) NOT NULL DEFAULT '0',
  `elo` smallint(5) unsigned NOT NULL DEFAULT '1000',
  PRIMARY KEY (`id`),
  UNIQUE KEY `UNIQUE_UNIQUE_ID` (`unique_id`) USING BTREE,
  KEY `rank` (`rank`)
) ENGINE=InnoDB AUTO_INCREMENT=10517 DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `player_connection`
--

DROP TABLE IF EXISTS `player_connection`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
 SET character_set_client = utf8mb4 ;
CREATE TABLE `player_connection` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `player` smallint(5) unsigned NOT NULL,
  `connect_date` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `disconnect_date` timestamp NULL DEFAULT NULL,
  `server` tinyint(3) unsigned NOT NULL,
  `map` smallint(5) unsigned NOT NULL,
  `ipv4` varchar(15) CHARACTER SET utf8 COLLATE utf8_unicode_ci DEFAULT NULL COMMENT 'This should get cleared at some point, not lasting more than 6 months',
  `country` tinyint(3) unsigned DEFAULT NULL COMMENT 'This will be redundant most of the time, but not always, as city is sometimes null (unknown) and then we wouldn''t be able to tell the country if we only tried to store the city',
  `city` smallint(5) unsigned DEFAULT NULL COMMENT 'There may be a country listed for this IP but not a city',
  `afk_time` decimal(12,6) DEFAULT NULL,
  `spectator_time` decimal(12,6) DEFAULT NULL,
  `replays_watched` smallint(5) unsigned DEFAULT NULL,
  `checkpoints` smallint(5) unsigned NOT NULL DEFAULT '0',
  `teleports` smallint(5) unsigned NOT NULL DEFAULT '0',
  `fps` decimal(8,4) DEFAULT NULL COMMENT 'Average framerate calculated ingame',
  `min_ping` decimal(6,2) DEFAULT NULL,
  `avg_ping` decimal(6,2) DEFAULT NULL COMMENT 'HL works with up to 4095ms ping, so no more than 4 digits for the integer part',
  `max_ping` decimal(6,2) DEFAULT NULL,
  `packet_loss` decimal(5,2) DEFAULT NULL COMMENT 'Average packet loss % calculated ingame',
  `hlkz_version` smallint(5) unsigned DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `UNIQUE_CONNECTION_PLAYER_DATE` (`player`,`connect_date`),
  KEY `player` (`player`),
  KEY `server` (`server`),
  KEY `map` (`map`) USING BTREE,
  KEY `country` (`country`),
  KEY `city` (`city`),
  KEY `hlkz_version` (`hlkz_version`),
  CONSTRAINT `fk_connection_city` FOREIGN KEY (`city`) REFERENCES `city` (`id`) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT `fk_connection_country` FOREIGN KEY (`country`) REFERENCES `country` (`id`) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT `fk_connection_hlkz_version` FOREIGN KEY (`hlkz_version`) REFERENCES `hlkz_version` (`id`) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT `fk_connection_map` FOREIGN KEY (`map`) REFERENCES `map` (`id`) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT `fk_connection_player` FOREIGN KEY (`player`) REFERENCES `player` (`id`) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT `fk_connection_server` FOREIGN KEY (`server`) REFERENCES `server` (`id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `player_name`
--

DROP TABLE IF EXISTS `player_name`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
 SET character_set_client = utf8mb4 ;
CREATE TABLE `player_name` (
  `id` mediumint(8) unsigned NOT NULL AUTO_INCREMENT,
  `player` smallint(5) unsigned NOT NULL,
  `name` varchar(50) COLLATE utf8_unicode_ci NOT NULL,
  `date` timestamp NOT NULL,
  PRIMARY KEY (`id`),
  KEY `player` (`player`),
  KEY `date` (`date`),
  KEY `name` (`name`),
  CONSTRAINT `fk_player_name_player` FOREIGN KEY (`player`) REFERENCES `player` (`id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB AUTO_INCREMENT=1057525 DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `player_setting`
--

DROP TABLE IF EXISTS `player_setting`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
 SET character_set_client = utf8mb4 ;
CREATE TABLE `player_setting` (
  `id` mediumint(8) unsigned NOT NULL AUTO_INCREMENT,
  `player` smallint(5) unsigned NOT NULL,
  `setting` varchar(50) COLLATE utf8_unicode_ci NOT NULL,
  `value` varchar(32) COLLATE utf8_unicode_ci NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `UNIQUE_PLAYER_SETTING` (`player`,`setting`) USING BTREE
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `privilege`
--

DROP TABLE IF EXISTS `privilege`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
 SET character_set_client = utf8mb4 ;
CREATE TABLE `privilege` (
  `id` tinyint(3) unsigned NOT NULL,
  `name` varchar(100) COLLATE utf8_unicode_ci NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `UNIQUE_NAME` (`name`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `profile`
--

DROP TABLE IF EXISTS `profile`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
 SET character_set_client = utf8mb4 ;
CREATE TABLE `profile` (
  `id` smallint(5) unsigned NOT NULL AUTO_INCREMENT,
  `player` smallint(5) unsigned DEFAULT NULL,
  `steamId64` varchar(32) CHARACTER SET utf8 COLLATE utf8_unicode_ci NOT NULL,
  `youtube` varchar(32) CHARACTER SET utf8 COLLATE utf8_unicode_ci DEFAULT NULL,
  `twitch` varchar(32) CHARACTER SET utf8 COLLATE utf8_unicode_ci DEFAULT NULL,
  `discord` varchar(32) CHARACTER SET utf8 COLLATE utf8_unicode_ci DEFAULT NULL,
  `x` varchar(32) CHARACTER SET utf8 COLLATE utf8_unicode_ci DEFAULT NULL,
  `status` varchar(128) CHARACTER SET utf8 COLLATE utf8_unicode_ci DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `profile_ibfk_1` (`player`),
  KEY `steamId64` (`steamId64`),
  CONSTRAINT `profile_ibfk_1` FOREIGN KEY (`player`) REFERENCES `player` (`id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB AUTO_INCREMENT=187 DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `profile_setting`
--

DROP TABLE IF EXISTS `profile_setting`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
 SET character_set_client = utf8mb4 ;
CREATE TABLE `profile_setting` (
  `id` smallint(5) unsigned NOT NULL AUTO_INCREMENT,
  `steamId64` varchar(32) CHARACTER SET utf8 COLLATE utf8_unicode_ci NOT NULL,
  `notify_beaten_wrs` tinyint(1) unsigned NOT NULL DEFAULT '0',
  `notify_all_wrs` tinyint(1) unsigned NOT NULL DEFAULT '0',
  PRIMARY KEY (`id`),
  KEY `profile_settings_ibfk1` (`steamId64`)
) ENGINE=InnoDB AUTO_INCREMENT=8 DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci ROW_FORMAT=COMPACT;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `rank`
--

DROP TABLE IF EXISTS `rank`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
 SET character_set_client = utf8mb4 ;
CREATE TABLE `rank` (
  `id` tinyint(3) unsigned NOT NULL,
  `name` varchar(32) COLLATE utf8_unicode_ci NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `UNIQUE_NAME` (`name`) USING BTREE
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `rank_privilege`
--

DROP TABLE IF EXISTS `rank_privilege`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
 SET character_set_client = utf8mb4 ;
CREATE TABLE `rank_privilege` (
  `id` smallint(5) unsigned NOT NULL AUTO_INCREMENT,
  `rank` tinyint(3) unsigned NOT NULL,
  `privilege` tinyint(3) unsigned NOT NULL,
  `value` varchar(50) COLLATE utf8_unicode_ci NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `UNIQUE_RANK_PRIVILEGE` (`rank`,`privilege`) USING BTREE
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `rank_requirement`
--

DROP TABLE IF EXISTS `rank_requirement`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
 SET character_set_client = utf8mb4 ;
CREATE TABLE `rank_requirement` (
  `id` tinyint(3) unsigned NOT NULL AUTO_INCREMENT,
  `rank` tinyint(3) unsigned NOT NULL,
  `requirement` tinyint(3) unsigned NOT NULL,
  `value1` varchar(100) COLLATE utf8_unicode_ci NOT NULL,
  `value2` varchar(100) COLLATE utf8_unicode_ci DEFAULT NULL,
  `value3` varchar(100) COLLATE utf8_unicode_ci DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `requirement` (`requirement`),
  KEY `rank` (`rank`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `requirement`
--

DROP TABLE IF EXISTS `requirement`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
 SET character_set_client = utf8mb4 ;
CREATE TABLE `requirement` (
  `id` tinyint(3) unsigned NOT NULL AUTO_INCREMENT,
  `name` varchar(100) CHARACTER SET utf8 COLLATE utf8_unicode_ci NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `UNIQUE_NAME` (`name`) USING BTREE
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `round`
--

DROP TABLE IF EXISTS `round`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
 SET character_set_client = utf8mb4 ;
CREATE TABLE `round` (
  `id` mediumint(8) unsigned NOT NULL AUTO_INCREMENT,
  `name` varchar(50) COLLATE utf8_unicode_ci NOT NULL,
  `competition` smallint(5) unsigned NOT NULL,
  `prev_round` mediumint(8) unsigned NOT NULL,
  `next_round` mediumint(8) unsigned NOT NULL,
  `format` varchar(32) COLLATE utf8_unicode_ci NOT NULL,
  `is_league` tinyint(1) NOT NULL,
  PRIMARY KEY (`id`),
  KEY `competition` (`competition`),
  KEY `prev_round` (`prev_round`),
  KEY `next_round` (`next_round`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `run`
--

DROP TABLE IF EXISTS `run`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
 SET character_set_client = utf8mb4 ;
CREATE TABLE `run` (
  `id` mediumint(8) unsigned NOT NULL AUTO_INCREMENT,
  `player` smallint(5) unsigned NOT NULL,
  `map` smallint(5) unsigned NOT NULL,
  `type` varchar(32) CHARACTER SET utf8 COLLATE utf8_unicode_ci NOT NULL,
  `time` decimal(12,6) NOT NULL,
  `date` timestamp NOT NULL,
  `checkpoints` smallint(5) unsigned NOT NULL DEFAULT '0',
  `teleports` smallint(5) unsigned NOT NULL DEFAULT '0',
  `is_no_reset` tinyint(1) DEFAULT '0',
  `fps` decimal(8,4) DEFAULT NULL,
  `avg_speed` decimal(11,2) DEFAULT NULL,
  `max_speed` decimal(11,2) DEFAULT NULL,
  `end_speed` decimal(11,2) DEFAULT NULL,
  `pre_speed` decimal(11,2) DEFAULT NULL,
  `pre_time` decimal(10,6) DEFAULT NULL,
  `timeloss_start` decimal(10,6) DEFAULT NULL,
  `timeloss_end` decimal(10,6) DEFAULT NULL,
  `ground_time` decimal(10,6) DEFAULT NULL,
  `ground_distance` decimal(13,4) DEFAULT NULL,
  `distance_2d` decimal(11,2) DEFAULT NULL,
  `distance_3d` decimal(11,2) DEFAULT NULL,
  `sync` decimal(10,6) DEFAULT NULL,
  `speedgain` decimal(10,6) DEFAULT NULL,
  `jumps` mediumint(8) unsigned DEFAULT NULL,
  `ducktaps` mediumint(8) unsigned DEFAULT NULL,
  `slowdowns` mediumint(8) unsigned DEFAULT NULL,
  `play_session` mediumint(8) unsigned DEFAULT NULL,
  `hlkz_version` smallint(5) unsigned DEFAULT NULL,
  `is_valid` tinyint(1) NOT NULL DEFAULT '1',
  PRIMARY KEY (`id`),
  UNIQUE KEY `UNIQUE_PLAYER_RUN_DATE` (`player`,`map`,`date`,`type`) USING BTREE,
  KEY `map` (`map`),
  KEY `player` (`player`),
  KEY `date` (`date`),
  KEY `type` (`type`),
  KEY `time` (`time`),
  KEY `hlkz_version` (`hlkz_version`),
  CONSTRAINT `fk_run_hlkz_version` FOREIGN KEY (`hlkz_version`) REFERENCES `hlkz_version` (`id`) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT `fk_run_map` FOREIGN KEY (`map`) REFERENCES `map` (`id`) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT `fk_run_player` FOREIGN KEY (`player`) REFERENCES `player` (`id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB AUTO_INCREMENT=1231118 DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_0900_ai_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'ONLY_FULL_GROUP_BY,STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
/*!50003 CREATE*/ /*!50017 DEFINER=`root`@`localhost`*/ /*!50003 TRIGGER `WorldRecordRun` AFTER INSERT ON `run` FOR EACH ROW BEGIN
	IF new.time <= GetMapWrTime(new.map, new.type) OR GetMapWrTime(new.map, new.type) IS NULL THEN
        INSERT INTO world_record(map, player, run, time, type, date)
        VALUES(new.map, new.player, new.id, new.time, new.type, new.date);
    END IF;
END */;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_unicode_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'ONLY_FULL_GROUP_BY,STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
/*!50003 CREATE*/ /*!50017 DEFINER=`root`@`localhost`*/ /*!50003 TRIGGER `WorldRecordInvalidate` AFTER UPDATE ON `run` FOR EACH ROW BEGIN
    IF NEW.is_valid = 0 THEN
        -- Insert into world_record if there isn't already an entry with the same run ID
        INSERT INTO world_record (map, player, run, time, type, date)
        SELECT
            NEW.map,
            r.player,
            r.id AS runId,
            r.time,
            NEW.type,
            r.date
        FROM
            run r
        WHERE
            r.is_valid = TRUE
            AND r.map = NEW.map
            AND r.type = NEW.type
            AND r.time = (
                SELECT MIN(r2.time)
                FROM run r2
                WHERE r2.is_valid = TRUE
                AND r2.map = r.map
                AND r2.type = r.type
            )
            AND NOT EXISTS (
                SELECT 1
                FROM world_record
                WHERE run = r.id
            )
        ORDER BY
            r.time ASC;
    END IF;
END */;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;

--
-- Table structure for table `run_category`
--

DROP TABLE IF EXISTS `run_category`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
 SET character_set_client = utf8mb4 ;
CREATE TABLE `run_category` (
  `id` tinyint(3) unsigned NOT NULL AUTO_INCREMENT,
  `name` varchar(32) COLLATE utf8_unicode_ci NOT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=7 DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `run_replay`
--

DROP TABLE IF EXISTS `run_replay`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
 SET character_set_client = utf8mb4 ;
CREATE TABLE `run_replay` (
  `id` mediumint(8) unsigned NOT NULL AUTO_INCREMENT,
  `player` smallint(5) unsigned NOT NULL,
  `run` mediumint(8) unsigned NOT NULL,
  `date` timestamp NOT NULL,
  `fps` decimal(8,4) NOT NULL,
  `times_replayed` mediumint(8) unsigned NOT NULL,
  PRIMARY KEY (`id`),
  KEY `player` (`player`),
  KEY `run` (`run`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `run_type`
--

DROP TABLE IF EXISTS `run_type`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
 SET character_set_client = utf8mb4 ;
CREATE TABLE `run_type` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `run` mediumint(8) unsigned NOT NULL,
  `category` tinyint(3) unsigned NOT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `server`
--

DROP TABLE IF EXISTS `server`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
 SET character_set_client = utf8mb4 ;
CREATE TABLE `server` (
  `id` tinyint(3) unsigned NOT NULL AUTO_INCREMENT,
  `ipv4_port` varchar(21) COLLATE utf8_unicode_ci NOT NULL,
  `name` varchar(64) COLLATE utf8_unicode_ci NOT NULL,
  `city` smallint(5) unsigned NOT NULL,
  `players` tinyint(4) NOT NULL,
  `max_players` tinyint(4) NOT NULL,
  `password` tinyint(1) NOT NULL,
  `current_map` smallint(5) unsigned NOT NULL,
  `next_map` smallint(5) unsigned NOT NULL,
  `next_map_date` timestamp NOT NULL,
  `game_mod` tinyint(3) unsigned NOT NULL,
  `last_seen` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `hlkz_version` smallint(5) unsigned DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `UNIQUE_IP` (`ipv4_port`),
  KEY `city` (`city`),
  KEY `hlkz_version` (`hlkz_version`),
  KEY `current_map` (`current_map`),
  KEY `next_map` (`next_map`),
  KEY `game_mod` (`game_mod`)
) ENGINE=InnoDB AUTO_INCREMENT=6 DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `server_map`
--

DROP TABLE IF EXISTS `server_map`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
 SET character_set_client = utf8mb4 ;
CREATE TABLE `server_map` (
  `id` smallint(5) unsigned NOT NULL AUTO_INCREMENT,
  `server` tinyint(3) unsigned NOT NULL,
  `map` smallint(5) unsigned NOT NULL,
  `insert_date` timestamp NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `UNIQUE_SERVER_MAP` (`server`,`map`) USING BTREE
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `split`
--

DROP TABLE IF EXISTS `split`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
 SET character_set_client = utf8mb4 ;
CREATE TABLE `split` (
  `id` smallint(5) unsigned NOT NULL AUTO_INCREMENT,
  `name` varchar(16) CHARACTER SET utf8 COLLATE utf8_unicode_ci NOT NULL,
  `displayname` varchar(31) CHARACTER SET utf8 COLLATE utf8_unicode_ci DEFAULT NULL,
  `map` smallint(5) unsigned NOT NULL,
  `split_trigger` mediumint(8) unsigned DEFAULT NULL,
  `next` varchar(16) CHARACTER SET utf8 COLLATE utf8_unicode_ci DEFAULT NULL,
  `is_lap_start` tinyint(1) NOT NULL DEFAULT '0',
  `is_run_end` tinyint(1) NOT NULL DEFAULT '0',
  `is_official` tinyint(1) NOT NULL DEFAULT '0',
  `is_trashed` tinyint(1) NOT NULL DEFAULT '0',
  PRIMARY KEY (`id`),
  UNIQUE KEY `UNIQUE_NAME_MAP` (`name`,`map`) USING BTREE,
  KEY `map` (`map`),
  KEY `split_trigger` (`split_trigger`)
) ENGINE=InnoDB AUTO_INCREMENT=78 DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci ROW_FORMAT=COMPACT;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `split_run`
--

DROP TABLE IF EXISTS `split_run`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
 SET character_set_client = utf8mb4 ;
CREATE TABLE `split_run` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `run` mediumint(8) unsigned DEFAULT NULL,
  `player` smallint(5) unsigned DEFAULT NULL,
  `type` varchar(32) CHARACTER SET utf8 COLLATE utf8_unicode_ci NOT NULL,
  `is_no_reset` tinyint(1) DEFAULT '0',
  `split` smallint(5) unsigned NOT NULL,
  `lap` smallint(5) unsigned DEFAULT NULL,
  `time` decimal(12,6) NOT NULL,
  `date` timestamp NOT NULL,
  `is_valid` tinyint(1) NOT NULL DEFAULT '1',
  `fps` decimal(8,4) DEFAULT NULL,
  `avg_speed` decimal(8,2) DEFAULT NULL,
  `end_speed` decimal(8,2) DEFAULT NULL,
  `max_speed` decimal(8,2) DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `UNIQUE_SPLIT` (`split`,`player`,`lap`,`date`),
  KEY `run` (`run`),
  KEY `player` (`player`) USING BTREE,
  KEY `date` (`date`),
  KEY `split` (`split`),
  CONSTRAINT `fk_split_run_player` FOREIGN KEY (`player`) REFERENCES `player` (`id`) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT `fk_split_run_run` FOREIGN KEY (`run`) REFERENCES `run` (`id`) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT `fk_split_run_split` FOREIGN KEY (`split`) REFERENCES `split` (`id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB AUTO_INCREMENT=105772 DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci ROW_FORMAT=COMPACT;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `split_trigger`
--

DROP TABLE IF EXISTS `split_trigger`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
 SET character_set_client = utf8mb4 ;
CREATE TABLE `split_trigger` (
  `id` mediumint(8) unsigned NOT NULL AUTO_INCREMENT,
  `author` smallint(5) unsigned DEFAULT NULL,
  `creation_date` timestamp NOT NULL,
  `min_x` decimal(12,6) DEFAULT NULL,
  `min_y` decimal(12,6) DEFAULT NULL,
  `min_z` decimal(12,6) DEFAULT NULL,
  `max_x` decimal(12,6) DEFAULT NULL,
  `max_y` decimal(12,6) DEFAULT NULL,
  `max_z` decimal(12,6) DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci ROW_FORMAT=COMPACT;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `webpush_subscription`
--

DROP TABLE IF EXISTS `webpush_subscription`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
 SET character_set_client = utf8mb4 ;
CREATE TABLE `webpush_subscription` (
  `id` smallint(5) unsigned NOT NULL AUTO_INCREMENT,
  `steamId64` varchar(32) CHARACTER SET utf8 COLLATE utf8_unicode_ci NOT NULL,
  `webpush_subscription` json NOT NULL,
  PRIMARY KEY (`id`),
  KEY `webpush_subscription_ibfk_2` (`steamId64`) USING BTREE,
  CONSTRAINT `webpush_subscription_ibfk_2` FOREIGN KEY (`steamId64`) REFERENCES `profile` (`steamId64`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB AUTO_INCREMENT=29 DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `world_record`
--

DROP TABLE IF EXISTS `world_record`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
 SET character_set_client = utf8mb4 ;
CREATE TABLE `world_record` (
  `id` mediumint(8) unsigned NOT NULL AUTO_INCREMENT,
  `map` smallint(5) unsigned NOT NULL,
  `player` smallint(5) unsigned NOT NULL,
  `run` mediumint(8) unsigned NOT NULL,
  `time` decimal(12,6) NOT NULL,
  `type` varchar(32) CHARACTER SET utf8 COLLATE utf8_unicode_ci NOT NULL,
  `date` timestamp NOT NULL,
  `is_valid` tinyint(1) NOT NULL DEFAULT '1',
  PRIMARY KEY (`id`),
  KEY `map` (`map`),
  KEY `player` (`player`),
  KEY `run` (`run`),
  CONSTRAINT `map` FOREIGN KEY (`map`) REFERENCES `map` (`id`) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT `player` FOREIGN KEY (`player`) REFERENCES `player` (`id`) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT `run` FOREIGN KEY (`run`) REFERENCES `run` (`id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB AUTO_INCREMENT=35565 DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci ROW_FORMAT=COMPACT;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_unicode_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'ONLY_FULL_GROUP_BY,STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
/*!50003 CREATE*/ /*!50017 DEFINER=`root`@`localhost`*/ /*!50003 TRIGGER `WorldRecordNotification` AFTER INSERT ON `world_record` FOR EACH ROW BEGIN
    DECLARE mapId INT;

    -- Get the map ID for the newly inserted world_record
    SELECT map INTO mapId FROM world_record WHERE id = NEW.id;

    -- Insert notifications for all steamId64 with the same map ID
    INSERT INTO world_record_notification(steamId64, world_record)
    SELECT ms.steamId64, NEW.id
    FROM map_subscription ms
	JOIN profile_setting ps ON ms.steamId64 = ps.steamId64
    WHERE ms.map = mapId
      AND NEW.time <= GetMapWrTime(ms.map, NEW.type)
      AND NOT EXISTS (
          SELECT 1
          FROM world_record wr
          JOIN profile p ON wr.player = p.player
          JOIN profile_setting ps ON p.steamId64 = ps.steamId64
            AND ps.notify_beaten_wrs = 1
            AND wr.time = (
                SELECT MIN(wr_inner.time)
                  FROM world_record wr_inner
                  WHERE wr_inner.map = mapId
                    AND wr_inner.type = NEW.type
                    AND wr_inner.time > NEW.time
            )
      );
END */;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_unicode_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'ONLY_FULL_GROUP_BY,STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
/*!50003 CREATE*/ /*!50017 DEFINER=`root`@`localhost`*/ /*!50003 TRIGGER `TakenWorldRecordNotification` AFTER INSERT ON `world_record` FOR EACH ROW BEGIN
    DECLARE mapId INT;

    -- Get the map ID for the newly inserted world_record
    SELECT map INTO mapId FROM world_record WHERE id = NEW.id;

    -- Insert notification for the previous world record holder with notify_beaten_wrs set to 1
    INSERT INTO world_record_notification(steamId64, world_record, type)
    SELECT pr.steamId64, NEW.id, 'stolen'
    FROM world_record wr
    JOIN profile pr ON wr.player = pr.player
    JOIN profile_setting ps ON pr.steamId64 = ps.steamId64
    WHERE wr.map = mapId
      AND wr.type = NEW.type
      AND NEW.time <= GetMapWrTime(wr.map, NEW.type) -- Ensure the new time is less than or equal to the existing world record time
      AND ps.notify_beaten_wrs = 1
      AND wr.player != NEW.player -- Do not insert if player beats their own WR
      AND wr.time = (
          SELECT MIN(wr_inner.time)
          FROM world_record wr_inner
          WHERE wr_inner.map = mapId
            AND wr_inner.type = NEW.type
            AND wr_inner.time > NEW.time
      )
      LIMIT 1; -- Ensure only one notification is inserted for the previous world record holder
END */;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_unicode_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'ONLY_FULL_GROUP_BY,STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
/*!50003 CREATE*/ /*!50017 DEFINER=`root`@`localhost`*/ /*!50003 TRIGGER `AllWorldRecordNotification` AFTER INSERT ON `world_record` FOR EACH ROW BEGIN
    DECLARE mapId INT;

    -- Get the map ID for the newly inserted world_record
    SELECT map INTO mapId FROM world_record WHERE id = NEW.id;

    -- Insert notifications for all steamId64 with the same map ID from profile_setting
    INSERT INTO world_record_notification(steamId64, world_record)
    SELECT DISTINCT ps.steamId64, NEW.id
    FROM profile_setting ps
	JOIN profile p ON ps.steamId64 = p.steamId64
	JOIN world_record wr ON p.player = wr.player
	-- Only insert for users who subscribe to all WR notifications
    WHERE ps.notify_all_wrs = 1
	  AND NEW.type = 'pure'
	  AND wr.player != NEW.player -- Do not insert to the player who beat the WR (if they fall into the criteria)
      AND NOT EXISTS (
          SELECT 1
          FROM map_subscription ms
          JOIN world_record wr ON ms.map = wr.map
		-- Do not insert if user is following a map, another trigger should take care of this
          WHERE ms.steamId64 = ps.steamId64
            AND ms.map = mapId

			-- Do not insert if user is following a map, and has stolen WR notifications enabled, another trigger will take care of it
            AND ps.notify_beaten_wrs = 1
            OR wr.time = (
                SELECT MIN(wr_inner.time)
                  FROM world_record wr_inner
                  WHERE wr_inner.map = mapId
                    AND wr_inner.type = NEW.type
                    AND wr_inner.time > NEW.time
            )
      );
END */;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;

--
-- Table structure for table `world_record_notification`
--

DROP TABLE IF EXISTS `world_record_notification`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
 SET character_set_client = utf8mb4 ;
CREATE TABLE `world_record_notification` (
  `id` smallint(5) unsigned NOT NULL AUTO_INCREMENT,
  `steamId64` varchar(32) CHARACTER SET utf8 COLLATE utf8_unicode_ci NOT NULL,
  `world_record` mediumint(8) unsigned NOT NULL,
  `date` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `is_read` tinyint(1) NOT NULL DEFAULT '0',
  `is_cleared` tinyint(1) NOT NULL DEFAULT '0',
  `is_pushed` tinyint(1) NOT NULL DEFAULT '0',
  `type` varchar(32) CHARACTER SET utf8 COLLATE utf8_unicode_ci NOT NULL DEFAULT 'generic' COMMENT 'Used to determine what kind of notification text to display',
  PRIMARY KEY (`id`),
  KEY `steamid` (`steamId64`),
  KEY `wr` (`world_record`),
  CONSTRAINT `wr_notification_ibfk1` FOREIGN KEY (`steamId64`) REFERENCES `profile` (`steamId64`) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT `wr_notification_ibfk2` FOREIGN KEY (`world_record`) REFERENCES `world_record` (`id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB AUTO_INCREMENT=3660 DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping routines for database 'hlkz1'
--
/*!50003 DROP FUNCTION IF EXISTS `GetMapRank10Time` */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_unicode_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'ONLY_FULL_GROUP_BY,STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
CREATE DEFINER=`root`@`localhost` FUNCTION `GetMapRank10Time`(`mapId` SMALLINT UNSIGNED, `runType` VARCHAR(32)) RETURNS decimal(15,6)
    DETERMINISTIC
BEGIN
	DECLARE result DECIMAL(15,6);

            SELECT
                r.time
        	INTO
        		result
            FROM
                run r
            INNER JOIN player p ON
                p.id = r.player
            INNER JOIN player_name pn ON
                pn.player = r.player AND pn.date = r.date
            WHERE
                r.is_valid = TRUE AND r.map = mapId AND r.type = runType AND (r.player, r.time) IN(
                    SELECT
                    r2.player,
                    MIN(r2.time) AS minTime
                    FROM run r2
                    WHERE
                    r2.is_valid = TRUE
                    AND r2.map = mapId
                    AND r2.type = runType
                    GROUP BY r2.player
                    ORDER BY minTime ASC
                )
            ORDER BY r.time ASC
            LIMIT 9, 1;

    RETURN result;
END ;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 DROP FUNCTION IF EXISTS `GetMapRankNTime` */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_unicode_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'ONLY_FULL_GROUP_BY,STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
CREATE DEFINER=`root`@`localhost` FUNCTION `GetMapRankNTime`(`mapId` SMALLINT UNSIGNED, `runType` VARCHAR(32), `rankN` INT UNSIGNED) RETURNS decimal(15,6)
    DETERMINISTIC
BEGIN
	DECLARE result DECIMAL(15,6);
    DECLARE rankNumber INT UNSIGNED;
    
    # rank is a reserved word in MySQL, that's why I named it rankN
    SET rankNumber = rankN - 1;
    
    SELECT
        r.time
    INTO
        result
    FROM
        run r
    INNER JOIN player p ON
        p.id = r.player
    INNER JOIN player_name pn ON
        pn.player = r.player AND pn.date = r.date
    WHERE
        r.is_valid = TRUE AND r.map = mapId AND r.type = runType AND (r.player, r.time) IN (
            SELECT
                r2.player,
                MIN(r2.time) AS minTime
            FROM run r2
            WHERE
            	r2.is_valid = TRUE
                AND r2.map = mapId
                AND r2.type = runType
            GROUP BY r2.player
            ORDER BY minTime ASC
        )
    ORDER BY r.time ASC
    LIMIT rankNumber, 1;

    RETURN result;
END ;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 DROP FUNCTION IF EXISTS `GetMapTop15SumTime` */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_unicode_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'ONLY_FULL_GROUP_BY,STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
CREATE DEFINER=`root`@`localhost` FUNCTION `GetMapTop15SumTime`(`mapId` SMALLINT UNSIGNED, `runType` VARCHAR(32)) RETURNS decimal(15,6)
    DETERMINISTIC
BEGIN
	DECLARE result DECIMAL(15, 6);

    SELECT
    	SUM(t.time)
    INTO
    	result
    FROM (
        SELECT
        r.time
        FROM
            run r
        INNER JOIN player p ON
            p.id = r.player
        INNER JOIN player_name pn ON
            pn.player = r.player AND pn.date = r.date
        WHERE
            r.is_valid = TRUE AND r.map = mapId AND r.type = runType AND (r.player, r.time) IN (
                SELECT
                r2.player,
                MIN(r2.time) AS minTime
                FROM run r2
                WHERE
                r2.is_valid = TRUE
                AND r2.map = mapId
                AND r2.type = runType
                GROUP BY r2.player
                ORDER BY minTime ASC
            )
        ORDER BY r.time ASC
        LIMIT 15
    ) AS t;

    RETURN result;
END ;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 DROP FUNCTION IF EXISTS `GetMapTopNRunsAvgTime` */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_unicode_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'ONLY_FULL_GROUP_BY,STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
CREATE DEFINER=`root`@`localhost` FUNCTION `GetMapTopNRunsAvgTime`(
	mapId SMALLINT UNSIGNED,
    runType VARCHAR(32),
    until INT UNSIGNED
) RETURNS decimal(15,6)
    DETERMINISTIC
BEGIN
    DECLARE result DECIMAL(15,6);
    DECLARE upperLimit INT UNSIGNED;
    
    SET upperLimit = until;

    SELECT
        AVG(t.time)
    INTO
    	result
    FROM (
        SELECT r.time
        FROM run r
        WHERE r.map = mapId AND r.type = runType AND r.is_valid = TRUE
        ORDER BY r.time ASC
        LIMIT upperLimit
    ) AS t;
    
	RETURN result;
END ;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 DROP FUNCTION IF EXISTS `GetMapWrTime` */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_0900_ai_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'ONLY_FULL_GROUP_BY,STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
CREATE DEFINER=`execut4ble`@`%` FUNCTION `GetMapWrTime`(`mapId` SMALLINT UNSIGNED, `type` VARCHAR(32)) RETURNS decimal(12,6)
    READS SQL DATA
BEGIN
	DECLARE result DECIMAL(12,6);

	SELECT MIN(wr.time)
	    INTO result
	    FROM world_record wr
	    INNER JOIN run r ON wr.run = r.id
	    WHERE wr.map = mapId AND r.is_valid = TRUE 
	   	AND (type = 'pro' OR wr.type = type);

    RETURN result;
END ;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 DROP PROCEDURE IF EXISTS `CopyRuns` */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_unicode_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'ONLY_FULL_GROUP_BY,STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
CREATE DEFINER=`root`@`localhost` PROCEDURE `CopyRuns`(IN `fromMapId` SMALLINT, IN `toMapId` SMALLINT)
    MODIFIES SQL DATA
INSERT INTO
	run (`player`, `map`, `type`, `time`, `date`, `checkpoints`, `teleports`, `is_no_reset`, `fps`, `start_speed`, `end_speed`, `avg_speed`, `max_speed`, `play_session`, `hlkz_version`, `is_valid`)
	SELECT player, toMapId, type, time, date, checkpoints, teleports, is_no_reset, fps, start_speed, end_speed, avg_speed, max_speed, play_session, hlkz_version, is_valid
    	FROM run
        WHERE map = fromMapId ;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 DROP PROCEDURE IF EXISTS `GetCurrentMapWrsByMapName` */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_unicode_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'ONLY_FULL_GROUP_BY,STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
CREATE DEFINER=`execut4ble`@`%` PROCEDURE `GetCurrentMapWrsByMapName`(IN `mapName` VARCHAR(255))
BEGIN
    DECLARE mapId INT;

    -- Get the map ID based on the map name
    SELECT id INTO mapId FROM map WHERE name = mapName;

    -- Check if the map ID was found
    IF mapId IS NOT NULL THEN
        -- Use the map ID in your getMapWrTime function
        SELECT getMapWrTime(mapId, 'pure') AS pure_wr, getMapWrTime(mapId, 'pro') AS pro_wr;
    ELSE
        -- Handle the case where the map name was not found
        SELECT 'Map not found' AS result;
    END IF;
END ;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 DROP PROCEDURE IF EXISTS `InsertFailedAttempt` */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_unicode_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'ONLY_FULL_GROUP_BY,STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
CREATE DEFINER=`root`@`localhost` PROCEDURE `InsertFailedAttempt`(IN `playerId` SMALLINT UNSIGNED, IN `mapId` SMALLINT UNSIGNED, IN `topType` VARCHAR(32), IN `runTime` DECIMAL(12,6), IN `runStartDate` DATETIME, IN `runDate` DATETIME, IN `x` DECIMAL(12,6), IN `y` DECIMAL(12,6), IN `z` DECIMAL(12,6), IN `fps` DECIMAL(8,4), IN `avgSpeed` DECIMAL(11,2), IN `maxSpeed` DECIMAL(11,2), IN `preSpeed` DECIMAL(11,2), IN `preTime` DECIMAL(10,6), IN `timelossStart` DECIMAL(10,6), IN `groundTime` DECIMAL(10,6), IN `groundDistance` DECIMAL(13,4), IN `distance2D` DECIMAL(11,2), IN `distance3D` DECIMAL(11,2), IN `sync` DECIMAL(10,6), IN `speedgain` DECIMAL(10,6), IN `jumps` MEDIUMINT UNSIGNED, IN `ducktaps` MEDIUMINT UNSIGNED, IN `slowdowns` MEDIUMINT UNSIGNED, IN `hlkzVersion` SMALLINT UNSIGNED)
    MODIFIES SQL DATA
BEGIN
	DECLARE faId INT(10) UNSIGNED;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION 
    BEGIN
          ROLLBACK;
    END;
    START TRANSACTION;

        INSERT INTO failed_attempt (player, map, type, time, date, fail_x, fail_y, fail_z, fps, avg_speed, max_speed, pre_speed, pre_time, timeloss_start, ground_time, ground_distance, distance_2d, distance_3d, sync, speedgain, jumps, ducktaps, slowdowns, hlkz_version)
        SELECT playerId, mapId, topType, runTime, runDate, x, y, z, fps, avgSpeed, maxSpeed, preSpeed, preTime, timelossStart, groundTime, groundDistance, distance2D, distance3D, sync, speedgain, jumps, ducktaps, slowdowns, hlkzVersion
        FROM (select 1) as a
        WHERE NOT EXISTS(
            SELECT player, map, type, time, date, fail_x, fail_y, fail_z
            FROM failed_attempt
            WHERE player = playerId AND date = runDate AND type = topType AND time = runTime
        )
        LIMIT 1;
        
        SELECT fa.id
        INTO faId
        FROM failed_attempt fa
        WHERE	fa.player = playerId
        	AND fa.map    = mapId
            AND fa.type   = topType
            AND fa.date   = runDate;
            
        SELECT faId;
    COMMIT;
END ;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 DROP PROCEDURE IF EXISTS `InsertHLKZVersion` */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_unicode_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'ONLY_FULL_GROUP_BY,STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
CREATE DEFINER=`root`@`localhost` PROCEDURE `InsertHLKZVersion`(IN `version` VARCHAR(32))
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION 
    BEGIN
          ROLLBACK;
    END;
    START TRANSACTION;       
        INSERT INTO hlkz_version (name)
        SELECT version
        FROM (select 1) as a
        WHERE NOT EXISTS(
            SELECT name
            FROM hlkz_version
            WHERE name = version
        )
        LIMIT 1;
        
        SELECT id FROM hlkz_version WHERE name = version;
    COMMIT;
END ;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 DROP PROCEDURE IF EXISTS `InsertPlayer` */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_unicode_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'ONLY_FULL_GROUP_BY,STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
CREATE DEFINER=`root`@`localhost` PROCEDURE `InsertPlayer`(IN `uniqueId` VARCHAR(32))
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION 
    BEGIN
          ROLLBACK;
    END;
    START TRANSACTION;       
        INSERT INTO player (unique_id)
        SELECT uniqueId
        FROM (select 1) as a
        WHERE NOT EXISTS(
            SELECT unique_id
            FROM player
            WHERE unique_id = uniqueId
        )
        LIMIT 1;
        
        SELECT id FROM player WHERE unique_id = uniqueId;
    COMMIT;
END ;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 DROP PROCEDURE IF EXISTS `InsertRunAndUpdateSplits` */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_unicode_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'ONLY_FULL_GROUP_BY,STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
CREATE DEFINER=`root`@`localhost` PROCEDURE `InsertRunAndUpdateSplits`(IN `playerId` SMALLINT(5) UNSIGNED, IN `mapId` SMALLINT(5) UNSIGNED, IN `topType` VARCHAR(32), IN `runTime` DECIMAL(12,6), IN `runStartDate` DATETIME, IN `runDate` DATETIME, IN `cps` SMALLINT(5) UNSIGNED, IN `tps` SMALLINT(5) UNSIGNED, IN `noReset` TINYINT(1))
BEGIN
		DECLARE runId MEDIUMINT(8) UNSIGNED;

        INSERT INTO run (player, map, type, time, date, checkpoints, teleports, is_no_reset)
        SELECT playerId, mapId, topType, runTime, runDate, cps, tps, noReset
        FROM (select 1) as a
        WHERE NOT EXISTS(
            SELECT player, map, type, time, date, checkpoints, teleports, is_no_reset
            FROM run
            WHERE player = playerId AND date = runDate AND type = topType
        )
        LIMIT 1;
        
        SELECT r.id
        INTO runId
        FROM run r
        WHERE	r.player = playerId
        	AND r.map = mapId
            AND r.type = topType
            AND r.date = runDate;
        
        UPDATE split_run
        SET run = runId
        WHERE 	player = playerId
            AND date BETWEEN runStartDate AND runDate;
            
        UPDATE lap_run
        SET run = runId
        WHERE 	player = playerId
            AND date BETWEEN runStartDate AND runDate;
            
        SELECT runId;
END ;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 DROP PROCEDURE IF EXISTS `InsertRunWithStatsAndUpdateSplits` */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_unicode_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'ONLY_FULL_GROUP_BY,STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
CREATE DEFINER=`root`@`localhost` PROCEDURE `InsertRunWithStatsAndUpdateSplits`(IN `playerId` SMALLINT(5) UNSIGNED, IN `mapId` SMALLINT(5) UNSIGNED, IN `topType` VARCHAR(32), IN `runTime` DECIMAL(12,6), IN `runStartDate` DATETIME, IN `runDate` DATETIME, IN `cps` SMALLINT(5) UNSIGNED, IN `tps` SMALLINT(5) UNSIGNED, IN `noReset` TINYINT(1), IN `fps` DECIMAL(8,4), IN `avgSpeed` DECIMAL(11,2), IN `maxSpeed` DECIMAL(11,2), IN `endSpeed` DECIMAL(11,2), IN `preSpeed` DECIMAL(11,2), IN `preTime` DECIMAL(10,6), IN `timelossStart` DECIMAL(10,6), IN `timelossEnd` DECIMAL(10,6), IN `groundTime` DECIMAL(10,6), IN `groundDistance` DECIMAL(13,4), IN `distance2D` DECIMAL(11,2), IN `distance3D` DECIMAL(11,2), IN `sync` DECIMAL(10,6), IN `speedgain` DECIMAL(10,6), IN `jumps` MEDIUMINT UNSIGNED, IN `ducktaps` MEDIUMINT UNSIGNED, IN `slowdowns` MEDIUMINT UNSIGNED, IN `hlkzVersion` SMALLINT UNSIGNED)
BEGIN
	DECLARE runId MEDIUMINT(8) UNSIGNED;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION 
    BEGIN
          ROLLBACK;
    END;
    START TRANSACTION;
    
        INSERT INTO run (player, map, type, time, date, checkpoints, teleports, is_no_reset, fps, avg_speed, max_speed, end_speed, pre_speed, pre_time, timeloss_start, timeloss_end, ground_time, ground_distance, distance_2d, distance_3d, sync, speedgain, jumps, ducktaps, slowdowns, hlkz_version)
        SELECT playerId, mapId, topType, runTime, runDate, cps, tps, noReset, fps, avgSpeed, maxSpeed, endSpeed, preSpeed, preTime, timelossStart, timelossEnd, groundTime, groundDistance, distance2D, distance3D, sync, speedgain, jumps, ducktaps, slowdowns, hlkzVersion
        FROM (select 1) as a
        WHERE NOT EXISTS(
            SELECT player, map, type, time, date, checkpoints, teleports, is_no_reset
            FROM run
            WHERE player = playerId AND date = runDate AND type = topType
        )
        LIMIT 1;
        
        SELECT r.id
        INTO runId
        FROM run r
        WHERE	r.player = playerId
        	AND r.map = mapId
            AND r.type = topType
            AND r.date = runDate;
        
        UPDATE split_run
        SET run = runId
        WHERE 	player = playerId
            AND date BETWEEN runStartDate AND runDate;
            
        UPDATE lap_run
        SET run = runId
        WHERE 	player = playerId
            AND date BETWEEN runStartDate AND runDate;
            
        SELECT runId;
    COMMIT;
END ;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 DROP PROCEDURE IF EXISTS `OldSelectGoldLaps` */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_unicode_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'ONLY_FULL_GROUP_BY,STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
CREATE DEFINER=`root`@`localhost` PROCEDURE `OldSelectGoldLaps`(IN `mapId` SMALLINT(5) UNSIGNED, IN `topType` VARCHAR(32))
    READS SQL DATA
BEGIN
SELECT
	p.unique_id,
    pn.name,
    lr.lap,
    lr.time
FROM
    lap_run lr
INNER JOIN(
    SELECT sub.player,
        sub.lap,
        MIN(sub.time) AS minTime
    FROM
        lap_run sub
    WHERE
        sub.map = mapId AND sub.type = topType AND sub.is_valid = TRUE
    GROUP BY
        sub.player,
        sub.lap
) AS sub
ON
    sub.player = lr.player AND sub.lap = lr.lap AND sub.minTime = lr.time
INNER JOIN(
    SELECT
        sub.player,
        MIN(sub.time) AS firstLapMinTime
    FROM
        lap_run sub
    WHERE
        sub.map = mapId AND sub.lap = 1 AND sub.type = topType AND sub.is_valid = TRUE
    GROUP BY
        sub.player
    ORDER BY firstLapMinTime
) AS sub2
ON
	sub2.player = lr.player
INNER JOIN player AS p ON p.id = lr.player
LEFT JOIN player_name AS pn
ON
	pn.player = lr.player AND pn.date = lr.date
WHERE
    lr.map = mapId AND lr.type = topType AND lr.is_valid = TRUE
ORDER BY sub2.firstLapMinTime, lr.player, lr.lap;
END ;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 DROP PROCEDURE IF EXISTS `OldSelectGoldProLaps` */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_unicode_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'ONLY_FULL_GROUP_BY,STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
CREATE DEFINER=`root`@`localhost` PROCEDURE `OldSelectGoldProLaps`(IN `mapId` SMALLINT(5) UNSIGNED)
    READS SQL DATA
BEGIN
SELECT
	p.unique_id,
    pn.name,
    lr.lap,
    lr.time
FROM
    lap_run lr
INNER JOIN(
    SELECT sub.player,
        sub.lap,
        MIN(sub.time) AS minTime
    FROM
        lap_run sub
    WHERE
        sub.map = mapId AND(
            sub.type = 'pure' OR sub.type = 'pro'
        ) AND sub.is_valid = TRUE
    GROUP BY
        sub.player,
        sub.lap
) AS sub
ON
    sub.player = lr.player AND sub.lap = lr.lap AND sub.minTime = lr.time
INNER JOIN(
    SELECT
        sub.player,
        MIN(sub.time) AS firstLapMinTime
    FROM
        lap_run sub
    WHERE
        sub.map = mapId AND sub.lap = 1 AND(
            sub.type = 'pure' OR sub.type = 'pro'
        ) AND sub.is_valid = TRUE
    GROUP BY
        sub.player
    ORDER BY firstLapMinTime
) AS sub2
ON
	sub2.player = lr.player
INNER JOIN player AS p ON p.id = lr.player
LEFT JOIN player_name AS pn
ON
	pn.player = lr.player AND pn.date = lr.date
WHERE
    lr.map = mapId AND(
        lr.type = 'pure' OR lr.type = 'pro'
    ) AND lr.is_valid = TRUE
ORDER BY sub2.firstLapMinTime, lr.player, lr.lap;
END ;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 DROP PROCEDURE IF EXISTS `SelectAverageRunStatsTopN` */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_unicode_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'ONLY_FULL_GROUP_BY,STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
CREATE DEFINER=`root`@`localhost` PROCEDURE `SelectAverageRunStatsTopN`(IN `mapId` SMALLINT UNSIGNED, IN `topLimit` INT UNSIGNED)
    READS SQL DATA
SELECT
	AVG(t.time) AS 'Min time',
	AVG(t.fps) AS 'Avg FPS',
    AVG(t.avg_speed) AS 'Avg spd',
    AVG(t.max_speed) AS 'Max spd',
    AVG(t.end_speed) AS 'End spd',
    AVG(t.pre_speed) AS 'Pre spd', 
    AVG(t.pre_time) AS 'Pre time',
    AVG(t.timeloss_start) AS 'Lost@Start',
    AVG(t.timeloss_end) AS 'Lost@End',
    AVG(t.ground_time) AS 'Gr time',
    AVG(t.ground_distance) AS 'Gr dist',
    AVG(t.distance_2d) AS 'Dist 2D',
    AVG(t.distance_3d) AS 'Dist 3D',
    AVG(t.sync) AS 'Sync%',
    AVG(t.speedgain) AS 'Speedgain%',
    ROUND(AVG(t.jumps), 0) AS 'Jumps',
    ROUND(AVG(t.ducktaps), 0) AS 'Ducktaps',
    ROUND(AVG(t.slowdowns), 0) AS 'Slowdowns'
FROM
(
    SELECT map, time, fps, avg_speed, max_speed, end_speed, pre_speed, pre_time, timeloss_start, timeloss_end, ground_time, ground_distance, distance_2d, distance_3d, sync, speedgain, jumps, ducktaps, slowdowns
    FROM run
    WHERE map = mapId AND type = 'pure' AND is_valid = TRUE
    ORDER BY time ASC
    LIMIT topLimit
) t
GROUP BY map ;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 DROP PROCEDURE IF EXISTS `SelectBestLaps` */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_unicode_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'ONLY_FULL_GROUP_BY,STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
CREATE DEFINER=`root`@`localhost` PROCEDURE `SelectBestLaps`(IN `mapId` SMALLINT(5) UNSIGNED, IN `topType` VARCHAR(32))
    READS SQL DATA
BEGIN
    SELECT lr.player, lr.lap, lr.time, lr.date
    FROM lap_run lr
    JOIN (
        SELECT sub.lap, MIN(sub.time) AS minTime
        FROM lap_run sub
        WHERE sub.map = mapId AND sub.type = topType AND sub.is_valid = TRUE
        GROUP BY sub.lap
    ) AS sub ON sub.lap = lr.lap AND sub.minTime = lr.time
    WHERE lr.map = mapId AND lr.type = topType AND lr.is_valid = TRUE
    ORDER BY lr.lap ASC;
END ;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 DROP PROCEDURE IF EXISTS `SelectBestProLaps` */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_unicode_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'ONLY_FULL_GROUP_BY,STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
CREATE DEFINER=`root`@`localhost` PROCEDURE `SelectBestProLaps`(IN `mapId` MEDIUMINT(5) UNSIGNED)
    READS SQL DATA
BEGIN
    SELECT lr.player, lr.lap, lr.time, lr.date
    FROM lap_run lr
    JOIN (
        SELECT sub.lap, MIN(sub.time) AS minTime
        FROM lap_run sub
        WHERE sub.map = mapId AND (sub.type = 'pure' OR sub.type = 'pro') AND sub.is_valid = TRUE
        GROUP BY sub.lap
    ) AS sub ON sub.lap = lr.lap AND sub.minTime = lr.time
    WHERE lr.map = mapId AND (lr.type = 'pure' OR lr.type = 'pro') AND lr.is_valid = TRUE
    ORDER BY lr.lap ASC;
END ;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 DROP PROCEDURE IF EXISTS `SelectBestProRunLaps` */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_unicode_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'ONLY_FULL_GROUP_BY,STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
CREATE DEFINER=`root`@`localhost` PROCEDURE `SelectBestProRunLaps`(IN `mapId` SMALLINT(5) UNSIGNED)
BEGIN
        SELECT
            t.id,
            (
            SELECT
                pn.name
            FROM
                player_name pn
            WHERE
                pn.player = lr.player AND pn.date >= t.date
            ORDER BY
                pn.date ASC
            LIMIT 1
        ) AS name, lr.lap, lr.time, lr.date
        FROM
            lap_run lr
        INNER JOIN(
            SELECT r.id,
                r.map,
                r.time,
                r.date
            FROM
                run r
        JOIN (
            SELECT
                MIN(r2.id) as maxRunId,
                r2.player,
                r2.time
            FROM
                run r2
            JOIN (
                    SELECT
                        r3.player,
                        MIN(r3.time) AS minTime
                    FROM
                        run r3
                    WHERE
                        r3.is_valid = TRUE AND r3.map = mapId AND(
                            r3.type = 'pure' OR r3.type = 'pro'
                        )
                    GROUP BY
                        r3.player
                    ORDER BY
                        minTime ASC
            ) AS sub2 ON r2.player = sub2.player AND r2.time = sub2.minTime
            GROUP BY
                r2.player,
                r2.time
        ) AS sub ON r.id = sub.maxRunId AND r.player = sub.player AND r.time = sub.time
        WHERE
            r.is_valid = TRUE AND r.map = mapId AND (r.type = 'pure' OR r.type = 'pro')
        ORDER BY
            r.time ASC
        ) AS t
        ON
            t.id = lr.run
        WHERE
            lr.is_valid = TRUE AND t.map = mapId AND (lr.type = 'pure' OR lr.type = 'pro')
        ORDER BY
            t.time ASC,
            lr.id ASC;
END ;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 DROP PROCEDURE IF EXISTS `SelectBestProRunSplits` */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_unicode_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'ONLY_FULL_GROUP_BY,STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
CREATE DEFINER=`root`@`localhost` PROCEDURE `SelectBestProRunSplits`(IN `mapId` SMALLINT(5) UNSIGNED)
BEGIN
        SELECT
            t.id,
            (
            SELECT
                pn.name
            FROM
                player_name pn
            WHERE
                pn.player = sr.player AND pn.date >= t.date
            ORDER BY
                pn.date ASC
            LIMIT 1
        ) AS NAME, sr.split, sr.lap, sr.time AS splitTime, sr.date
        FROM
            split_run sr
        INNER JOIN(
            SELECT r.id,
                r.map,
                r.time,
                r.date
            FROM
                run r
        JOIN (
            SELECT
                MIN(r2.id) as maxRunId,
                r2.player,
                r2.time
            FROM
                run r2
            JOIN (
                    SELECT
                        r3.player,
                        MIN(r3.time) AS minTime
                    FROM
                        run r3
                    WHERE
                        r3.is_valid = TRUE AND r3.map = mapId AND(
                            r3.type = 'pure' OR r3.type = 'pro'
                        )
                    GROUP BY
                        r3.player
                    ORDER BY
                        minTime ASC
            ) AS sub2 ON r2.player = sub2.player AND r2.time = sub2.minTime
            GROUP BY
                r2.player,
                r2.time
        ) AS sub ON r.id = sub.maxRunId AND r.player = sub.player AND r.time = sub.time
        WHERE
            r.is_valid = TRUE AND r.map = mapId AND (r.type = 'pure' OR r.type = 'pro')
        ORDER BY
            r.time ASC
        ) AS t
        ON
            t.id = sr.run
        WHERE
            sr.is_valid = TRUE AND t.map = mapId AND (sr.type = 'pure' OR sr.type = 'pro')
        ORDER BY
            t.time ASC,
            sr.id ASC;
END ;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 DROP PROCEDURE IF EXISTS `SelectBestRunLaps` */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_unicode_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'ONLY_FULL_GROUP_BY,STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
CREATE DEFINER=`root`@`localhost` PROCEDURE `SelectBestRunLaps`(IN `mapId` SMALLINT(5) UNSIGNED, IN `topType` VARCHAR(32))
BEGIN
    SELECT
        t.id,
        (
        SELECT
            pn.name
        FROM
            player_name pn
        WHERE
            pn.player = lr.player AND pn.date >= t.date
        ORDER BY
            pn.date ASC
        LIMIT 1
    ) AS name, lr.lap, lr.time, lr.date
    FROM
        lap_run lr
    INNER JOIN(
        SELECT
            r.id,
            r.map,
            r.time,
            r.date
        FROM
            run r
        JOIN(
            SELECT
                r2.player,
                MIN(r2.time) AS minTime
            FROM
                run r2
            WHERE
                r2.is_valid = TRUE AND r2.map = mapId AND r2.type = topType
            GROUP BY
                r2.player
            ORDER BY
                minTime ASC
        ) AS sub
    ON
        r.player = sub.player AND r.time = sub.minTime
    WHERE
        r.is_valid = TRUE AND r.map = mapId AND r.type = topType
    ORDER BY
        r.time ASC
    ) AS t
    ON
        t.id = lr.run
    WHERE
        lr.is_valid = TRUE AND t.map = mapId AND lr.type = topType
    ORDER BY
        t.time ASC,
        lr.id ASC;
END ;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 DROP PROCEDURE IF EXISTS `SelectBestRunSplits` */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_unicode_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'ONLY_FULL_GROUP_BY,STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
CREATE DEFINER=`root`@`localhost` PROCEDURE `SelectBestRunSplits`(IN `mapId` SMALLINT(5) UNSIGNED, IN `topType` VARCHAR(32))
BEGIN
    SELECT
        t.id,
        (
        SELECT
            pn.name
        FROM
            player_name pn
        WHERE
            pn.player = sr.player AND pn.date >= t.date
        ORDER BY
            pn.date ASC
        LIMIT 1
    ) AS name, sr.split, sr.lap, sr.time AS splitTime, sr.date
    FROM
        split_run sr
    INNER JOIN(
        SELECT r.id,
            r.map,
            r.time,
            r.date
        FROM
            run r
        JOIN(
            SELECT r2.player,
                MIN(r2.time) AS minTime
            FROM
                run r2
            WHERE
                r2.is_valid = TRUE AND r2.map = mapId AND r2.type = topType
            GROUP BY
                r2.player
            ORDER BY
                minTime ASC
        ) AS sub
    ON
        r.player = sub.player AND r.time = sub.minTime
    WHERE
        r.is_valid = TRUE AND r.map = mapId AND r.type = topType
    ORDER BY
        r.time ASC
    ) AS t
    ON
        t.id = sr.run
    WHERE
        sr.is_valid = TRUE AND t.map = mapId AND sr.type = topType
    ORDER BY
        t.time ASC,
        sr.id ASC;
END ;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 DROP PROCEDURE IF EXISTS `SelectBestRunStatsTopN` */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_unicode_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'ONLY_FULL_GROUP_BY,STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
CREATE DEFINER=`root`@`localhost` PROCEDURE `SelectBestRunStatsTopN`(IN `mapId` SMALLINT UNSIGNED, IN `topLimit` INT UNSIGNED)
    READS SQL DATA
SELECT
	MIN(t.time) AS 'Min time',
	MAX(t.fps) AS 'Avg FPS',
    MAX(t.avg_speed) AS 'Avg spd',
    MAX(t.max_speed) AS 'Max spd',
    MAX(t.end_speed) AS 'End spd',
    MAX(t.pre_speed) AS 'Pre spd', 
    MIN(t.pre_time) AS 'Pre time',
    MIN(t.timeloss_start) AS 'Lost@Start',
    MIN(t.timeloss_end) AS 'Lost@End',
    MIN(t.ground_time) AS 'Gr Time',
    MIN(t.ground_distance) AS 'Gr Dist',
    MIN(t.distance_2d) AS 'Dist 2D',
    MIN(t.distance_3d) AS 'Dist 3D',
    MAX(t.sync) AS 'Sync%',
    MAX(t.speedgain) AS 'Speedgain%',
    MIN(t.jumps) AS 'Jumps',
    MIN(t.ducktaps) AS 'Ducktaps',
    MIN(t.slowdowns) AS 'Slowdowns'
FROM
(
    SELECT map, time, fps, avg_speed, max_speed, end_speed, pre_speed, pre_time, timeloss_start, timeloss_end, ground_time, ground_distance, distance_2d, distance_3d, sync, speedgain, jumps, ducktaps, slowdowns
    FROM run
    WHERE map = mapId AND type = 'pure' AND is_valid = TRUE
    ORDER BY time ASC
    LIMIT topLimit
) t
GROUP BY map ;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 DROP PROCEDURE IF EXISTS `SelectGoldLaps` */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_unicode_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'ONLY_FULL_GROUP_BY,STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
CREATE DEFINER=`root`@`localhost` PROCEDURE `SelectGoldLaps`(IN `mapId` SMALLINT(5) UNSIGNED, IN `topType` VARCHAR(32))
    READS SQL DATA
BEGIN
SELECT DISTINCT
	p.unique_id,
    pn.name,
    lr.lap,
    lr.time,
    lr.player,
    sub2.firstLapMinTime
FROM
    lap_run lr
INNER JOIN(
    SELECT sub.player,
        sub.lap,
        MIN(sub.time) AS minTime
    FROM
        lap_run sub
    WHERE
        sub.map = mapId AND sub.type = topType AND sub.is_valid = TRUE
    GROUP BY
        sub.player,
        sub.lap
) AS sub
ON
    sub.player = lr.player AND sub.lap = lr.lap AND sub.minTime = lr.time
INNER JOIN(
    SELECT
        sub.player,
        MIN(sub.time) AS firstLapMinTime
    FROM
        lap_run sub
    WHERE
        sub.map = mapId AND sub.lap = 1 AND sub.type = topType AND sub.is_valid = TRUE
    GROUP BY
        sub.player
    ORDER BY firstLapMinTime
) AS sub2
ON
	sub2.player = lr.player
INNER JOIN player AS p ON p.id = lr.player
LEFT JOIN player_name AS pn
ON
	pn.player = lr.player AND pn.date = lr.date
WHERE
    lr.map = mapId AND lr.type = topType AND lr.is_valid = TRUE
ORDER BY sub2.firstLapMinTime, lr.player, lr.lap;
END ;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 DROP PROCEDURE IF EXISTS `SelectGoldProLaps` */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_unicode_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'ONLY_FULL_GROUP_BY,STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
CREATE DEFINER=`root`@`localhost` PROCEDURE `SelectGoldProLaps`(IN `mapId` SMALLINT(5) UNSIGNED)
    READS SQL DATA
BEGIN
SELECT DISTINCT
	p.unique_id,
    pn.name,
    lr.lap,
    lr.time,
    lr.player,
    sub2.firstLapMinTime
FROM
    lap_run lr
INNER JOIN(
    SELECT sub.player,
        sub.lap,
        MIN(sub.time) AS minTime
    FROM
        lap_run sub
    WHERE
        sub.map = mapId AND(
            sub.type = 'pure' OR sub.type = 'pro'
        ) AND sub.is_valid = TRUE
    GROUP BY
        sub.player,
        sub.lap
) AS sub
ON
    sub.player = lr.player AND sub.lap = lr.lap AND sub.minTime = lr.time
INNER JOIN(
    SELECT
        sub.player,
        MIN(sub.time) AS firstLapMinTime
    FROM
        lap_run sub
    WHERE
        sub.map = mapId AND sub.lap = 1 AND(
            sub.type = 'pure' OR sub.type = 'pro'
        ) AND sub.is_valid = TRUE
    GROUP BY
        sub.player
    ORDER BY firstLapMinTime
) AS sub2
ON
	sub2.player = lr.player
INNER JOIN player AS p ON p.id = lr.player
LEFT JOIN player_name AS pn
ON
	pn.player = lr.player AND pn.date = lr.date
WHERE
    lr.map = mapId AND(
        lr.type = 'pure' OR lr.type = 'pro'
    ) AND lr.is_valid = TRUE
ORDER BY sub2.firstLapMinTime, lr.player, lr.lap;
END ;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 DROP PROCEDURE IF EXISTS `SelectMapPbRuns` */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_unicode_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'ONLY_FULL_GROUP_BY,STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
CREATE DEFINER=`root`@`localhost` PROCEDURE `SelectMapPbRuns`(IN `mapId` SMALLINT UNSIGNED, IN `runType` VARCHAR(32))
    READS SQL DATA
SELECT
    r.id,
    p.unique_id,
    pn.name,
    r.checkpoints,
    r.teleports,
    r.time,
    UNIX_TIMESTAMP(r.date)
FROM
    run r
INNER JOIN player p ON
    p.id = r.player
INNER JOIN player_name pn ON
    pn.player = r.player AND pn.date = r.date
WHERE
    r.is_valid = TRUE AND r.map = mapId AND r.type = runType AND(r.player, r.time) IN(
    SELECT
        r2.player,
        MIN(r2.time) AS minTime
    FROM run r2
    WHERE
            r2.is_valid = TRUE
        AND r2.map = mapId
        AND r2.type = runType
    GROUP BY r2.player
    ORDER BY minTime ASC
)
ORDER BY r.time ASC ;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 DROP PROCEDURE IF EXISTS `SelectMapsPlayedByPlayer` */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_unicode_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'ONLY_FULL_GROUP_BY,STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
CREATE DEFINER=`root`@`localhost` PROCEDURE `SelectMapsPlayedByPlayer`(IN `playerId` INT)
    NO SQL
BEGIN
SELECT m.name AS 'Map name', t.bestTime AS 'PB time', r.date AS 'PB date'
    FROM (
        SELECT map, player, MIN(time) AS bestTime
          FROM run
          WHERE player = playerId AND type = 'pure' AND is_valid = TRUE
          GROUP BY map, player
    ) AS t
    INNER JOIN map AS m ON m.id = t.map
    INNER JOIN run AS r ON r.time = t.bestTime AND r.player = t.player AND r.map = t.map
    WHERE r.type = 'pure' AND r.is_valid = TRUE
    ORDER BY t.bestTime ASC;
END ;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 DROP PROCEDURE IF EXISTS `SelectMapsPlayedByPlayerNonPure` */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_unicode_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'ONLY_FULL_GROUP_BY,STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
CREATE DEFINER=`root`@`localhost` PROCEDURE `SelectMapsPlayedByPlayerNonPure`(IN `playerId` SMALLINT)
    NO SQL
BEGIN
SELECT
    m.name AS 'Map name',
    t.bestTime AS 'PB time',
    r.date AS 'PB date'
FROM
    (
    SELECT
        map,
        player,
        MIN(time) AS bestTime
    FROM
        run
    WHERE
        player = playerId AND type != 'pure' AND is_valid = TRUE
    GROUP BY
        map,
        player
) AS t
INNER JOIN map AS m
ON
    m.id = t.map
INNER JOIN run AS r
ON
    r.time = t.bestTime AND r.player = t.player AND r.map = t.map
WHERE
    r.type != 'pure' AND r.is_valid = TRUE AND m.id NOT IN(
    SELECT DISTINCT
        (map)
    FROM
        run
    WHERE
        player = playerId AND type = 'pure' AND is_valid = TRUE
)
ORDER BY
    r.date ASC;
END ;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 DROP PROCEDURE IF EXISTS `SelectMapsRunByPlayer` */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_unicode_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'ONLY_FULL_GROUP_BY,STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
CREATE DEFINER=`root`@`localhost` PROCEDURE `SelectMapsRunByPlayer`(IN `playerId` SMALLINT UNSIGNED)
    READS SQL DATA
SELECT m.name, COUNT(*) runs
FROM run r
INNER JOIN map m ON m.id = r.map
WHERE r.player = playerId
GROUP BY m.name  
ORDER BY runs DESC ;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 DROP PROCEDURE IF EXISTS `SelectMedalRewardingMaps` */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_unicode_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'ONLY_FULL_GROUP_BY,STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
CREATE DEFINER=`root`@`localhost` PROCEDURE `SelectMedalRewardingMaps`()
    READS SQL DATA
SELECT
	m.name AS 'Map name',
    t.wrTime AS 'WR time',
    GetMapTopNRunsAvgTime(m.id, 'pure', round(t.runs * 0.05)) AS 'Best 5% runs avg. time',
    (GetMapTop15SumTime(m.id, 'pure') / 15) AS 'Top 15 avg. time',
    GetMapRankNTime(m.id, 'pure', 10) AS '#10 time',
    GetMapRankNTime(m.id, 'pure', round(t2.runners / 2)) AS 'Mid time',
    t.avgTime AS 'Avg. time',
    t.totalTime AS 'Total time',
    t.runs AS 'Runs',
    t2.runners AS 'Runners'
FROM (
	SELECT r.map, MIN(r.time) wrTime, AVG(r.time) avgTime, SUM(r.time) totalTime, COUNT(*) runs
    FROM run r
    WHERE r.type = 'pure' AND r.is_valid = TRUE
    GROUP BY r.map
) AS t
INNER JOIN (
    SELECT r2.map, COUNT(r2.player) runners
    FROM (
        SELECT r3.map, r3.player
        FROM run r3
        WHERE r3.type = 'pure' AND r3.is_valid = TRUE
        GROUP BY r3.map, r3.player
    ) AS r2
    GROUP BY r2.map
) AS t2 ON t2.map = t.map
INNER JOIN map m ON m.id = t.map
HAVING t.runs > 50 AND t.avgTime > 10 AND t.totalTime > 8000 AND t2.runners > 15
ORDER BY t.totalTime DESC ;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 DROP PROCEDURE IF EXISTS `SelectPbNoResetRuns` */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_unicode_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'ONLY_FULL_GROUP_BY,STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
CREATE DEFINER=`execut4ble`@`%` PROCEDURE `SelectPbNoResetRuns`(IN `mapName` VARCHAR(64))
    READS SQL DATA
BEGIN
    SELECT t.unique_id, pn.name, t.average_time, t.runs, UNIX_TIMESTAMP(t.latest_run)
    FROM (
        SELECT p.unique_id, p.id AS pid, AVG(r.time) AS average_time, COUNT(*) AS runs, MAX(r.date) AS latest_run
        FROM run r
        INNER JOIN player p ON p.id = r.player
        INNER JOIN map m ON m.id = r.map
        WHERE
            r.is_valid
            AND r.is_no_reset = true
            AND m.name = mapName
        GROUP BY p.id
        ORDER BY average_time
    ) as t
    INNER JOIN player_name pn ON pn.player = t.pid AND pn.date = t.latest_run;
END ;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 DROP PROCEDURE IF EXISTS `SelectPbProRuns` */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_unicode_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'ONLY_FULL_GROUP_BY,STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
CREATE DEFINER=`execut4ble`@`%` PROCEDURE `SelectPbProRuns`(IN `mapId` SMALLINT(5))
    READS SQL DATA
BEGIN
    SELECT
        r.id,
        p.unique_id,
        pn.name,
        r.checkpoints,
        r.teleports,
        r.time,
        UNIX_TIMESTAMP(r.date)
    FROM run r
    INNER JOIN player p ON p.id = r.player
    INNER JOIN player_name pn ON pn.player = r.player AND pn.date = r.date
    JOIN (
            SELECT MAX(r2.id) as maxRunId, r2.player, r2.time
            FROM run r2
            JOIN (
                    SELECT r3.player, MIN(r3.time) AS minTime
                    FROM run r3
                    WHERE
                            r3.is_valid = TRUE
                        AND r3.map = mapId
                        AND (r3.type = 'pure' OR r3.type = 'pro')
                    GROUP BY r3.player
                    ORDER BY minTime ASC
            ) AS sub2 ON r2.player = sub2.player AND r2.time = sub2.minTime
            GROUP BY
                r2.player,
                r2.time
        ) AS sub ON r.id = sub.maxRunId AND r.player = sub.player AND r.time = sub.time
    ORDER BY r.time ASC;
END ;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 DROP PROCEDURE IF EXISTS `SelectPbProRunsByName` */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_unicode_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'ONLY_FULL_GROUP_BY,STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
CREATE DEFINER=`execut4ble`@`%` PROCEDURE `SelectPbProRunsByName`(IN `mapName` VARCHAR(64))
    READS SQL DATA
SELECT
        r.id,
        p.unique_id,
        pn.name,
        r.checkpoints,
        r.teleports,
        r.time,
        UNIX_TIMESTAMP(r.date) AS date
    FROM run r
    INNER JOIN player p ON p.id = r.player
    INNER JOIN player_name pn ON pn.player = r.player AND pn.date = r.date
    
    JOIN (
            SELECT MAX(r2.id) as maxRunId, r2.player, r2.time
            FROM run r2
            
            JOIN (
                    SELECT r3.player, MIN(r3.time) AS minTime
                    FROM run r3
                    INNER JOIN map AS m ON r3.map = m.id
                    WHERE
                            r3.is_valid = TRUE
                        AND m.name LIKE mapName
                		AND (r3.type IN ('pure', 'pro'))
                
                    GROUP BY r3.player
                    ORDER BY minTime ASC
            ) AS sub2 ON r2.player = sub2.player AND r2.time = sub2.minTime
            GROUP BY
                r2.player,
                r2.time
        ) AS sub ON r.id = sub.maxRunId AND r.player = sub.player AND r.time = sub.time
    ORDER BY r.time ASC ;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 DROP PROCEDURE IF EXISTS `SelectPbPureRunsByName` */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_unicode_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'ONLY_FULL_GROUP_BY,STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
CREATE DEFINER=`execut4ble`@`%` PROCEDURE `SelectPbPureRunsByName`(IN `mapName` VARCHAR(64))
    READS SQL DATA
SELECT
        r.id,
        p.unique_id,
        pn.name,
        r.checkpoints,
        r.teleports,
        r.time,
        UNIX_TIMESTAMP(r.date) AS date
    FROM run r
    INNER JOIN player p ON p.id = r.player
    INNER JOIN player_name pn ON pn.player = r.player AND pn.date = r.date
    
    JOIN (
            SELECT MAX(r2.id) as maxRunId, r2.player, r2.time
            FROM run r2
            
            JOIN (
                    SELECT r3.player, MIN(r3.time) AS minTime
                    FROM run r3
                    INNER JOIN map AS m ON r3.map = m.id
                    WHERE
                            r3.is_valid = TRUE
                        AND m.name LIKE mapName
                        AND (r3.type = 'pure')
                        
                    GROUP BY r3.player
                    ORDER BY minTime ASC
            ) AS sub2 ON r2.player = sub2.player AND r2.time = sub2.minTime
            GROUP BY
                r2.player,
                r2.time
        ) AS sub ON r.id = sub.maxRunId AND r.player = sub.player AND r.time = sub.time
    ORDER BY r.time ASC ;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 DROP PROCEDURE IF EXISTS `SelectPlayerGoldLaps` */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_unicode_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'ONLY_FULL_GROUP_BY,STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
CREATE DEFINER=`root`@`localhost` PROCEDURE `SelectPlayerGoldLaps`(IN `mapId` SMALLINT(5) UNSIGNED, IN `playerId` SMALLINT(5) UNSIGNED, IN `topType` VARCHAR(32))
    READS SQL DATA
BEGIN
    SELECT
        lr.lap,
        MIN(lr.time)
    FROM
        lap_run lr
    WHERE
        lr.map = mapId AND lr.player = playerId AND lr.type = topType AND lr.is_valid = TRUE
    GROUP BY
        lr.player,
        lr.lap;
END ;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 DROP PROCEDURE IF EXISTS `SelectPlayerGoldProLaps` */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_unicode_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'ONLY_FULL_GROUP_BY,STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
CREATE DEFINER=`root`@`localhost` PROCEDURE `SelectPlayerGoldProLaps`(IN `mapId` SMALLINT(5) UNSIGNED, IN `playerId` SMALLINT(5) UNSIGNED)
    READS SQL DATA
BEGIN
    SELECT
        lr.lap,
        MIN(lr.time)
    FROM
        lap_run lr
    WHERE
        lr.map = mapId AND lr.player = playerId AND (lr.type = 'pure' OR lr.type = 'pro') AND lr.is_valid = TRUE
    GROUP BY
        lr.player,
        lr.lap;
END ;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 DROP PROCEDURE IF EXISTS `SelectPlayerGoldProSplits` */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_unicode_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'ONLY_FULL_GROUP_BY,STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
CREATE DEFINER=`root`@`localhost` PROCEDURE `SelectPlayerGoldProSplits`(IN `mapId` SMALLINT(5) UNSIGNED, IN `playerId` SMALLINT(5) UNSIGNED)
    NO SQL
BEGIN
SELECT DISTINCT
    lr.split,
    lr.lap,
    MIN(lr.time) AS splitTime
FROM
    split_run lr
INNER JOIN split s ON
    s.id = lr.split
WHERE
    s.map = mapId AND lr.player = playerId AND (lr.type = 'pure' OR lr.type = 'pro') AND lr.is_valid = TRUE
GROUP BY
    lr.player,
    lr.lap,
    lr.split
ORDER BY
	lr.lap,
    lr.split;
END ;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 DROP PROCEDURE IF EXISTS `SelectPlayerGoldSplits` */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_unicode_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'ONLY_FULL_GROUP_BY,STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
CREATE DEFINER=`root`@`localhost` PROCEDURE `SelectPlayerGoldSplits`(IN `mapId` SMALLINT(5) UNSIGNED, IN `playerId` SMALLINT(5) UNSIGNED, IN `topType` VARCHAR(32))
    READS SQL DATA
BEGIN
	SELECT DISTINCT
        lr.split,
        lr.lap,
        MIN(lr.time) AS splitTime
    FROM
        split_run lr
    INNER JOIN split s ON
        s.id = lr.split
    WHERE
        s.map = mapId AND lr.player = playerId AND lr.type = topType AND lr.is_valid = TRUE
    GROUP BY
        lr.player,
        lr.lap,
        lr.split
    ORDER BY
        lr.lap,
        lr.split;
END ;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 DROP PROCEDURE IF EXISTS `SelectPlayerPbLaps` */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_unicode_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'ONLY_FULL_GROUP_BY,STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
CREATE DEFINER=`root`@`localhost` PROCEDURE `SelectPlayerPbLaps`(IN `mapId` SMALLINT(5) UNSIGNED, IN `playerId` SMALLINT(5) UNSIGNED, IN `topType` VARCHAR(32))
    READS SQL DATA
BEGIN
    SELECT lr.lap, lr.time
    FROM lap_run lr
    INNER JOIN (
            SELECT r.id, r.time
            FROM run r
            WHERE r.map = mapId AND r.player = playerId AND r.type = topType AND r.is_valid = TRUE
            ORDER BY r.time
            LIMIT 1
        ) AS r on r.id = lr.run
    ORDER BY lr.lap;
END ;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 DROP PROCEDURE IF EXISTS `SelectPlayerPbProLaps` */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_unicode_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'ONLY_FULL_GROUP_BY,STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
CREATE DEFINER=`root`@`localhost` PROCEDURE `SelectPlayerPbProLaps`(IN `mapId` SMALLINT(5) UNSIGNED, IN `playerId` SMALLINT(5) UNSIGNED)
    READS SQL DATA
BEGIN
    SELECT lr.lap, lr.time
    FROM lap_run lr
    INNER JOIN (
            SELECT r.id, r.time
            FROM run r
            WHERE r.map = mapId AND r.player = playerId AND (r.type = 'pure' OR r.type = 'pro') AND r.is_valid = TRUE
            ORDER BY r.time
            LIMIT 1
        ) AS r on r.id = lr.run
    ORDER BY lr.lap;
END ;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 DROP PROCEDURE IF EXISTS `SelectPlayerPbProSplits` */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_unicode_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'ONLY_FULL_GROUP_BY,STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
CREATE DEFINER=`root`@`localhost` PROCEDURE `SelectPlayerPbProSplits`(IN `mapId` SMALLINT(5) UNSIGNED, IN `playerId` SMALLINT(5) UNSIGNED)
    READS SQL DATA
BEGIN
    SELECT sr.split, sr.lap, sr.time
    FROM split_run sr
    INNER JOIN (
            SELECT r.id, r.time
            FROM run r
            WHERE r.map = mapId AND r.player = playerId AND (r.type = 'pure' OR r.type = 'pro') AND r.is_valid = TRUE
            ORDER BY r.time
            LIMIT 1
        ) AS r on r.id = sr.run
    ORDER BY sr.lap, sr.split;
END ;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 DROP PROCEDURE IF EXISTS `SelectPlayerPbPureRuns` */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_unicode_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'ONLY_FULL_GROUP_BY,STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
CREATE DEFINER=`execut4ble`@`%` PROCEDURE `SelectPlayerPbPureRuns`(IN `playerId` SMALLINT(5) UNSIGNED)
    READS SQL DATA
BEGIN
    SELECT m.name, t.bestTime
    FROM (
        SELECT map, MIN(time) AS bestTime
          FROM run
          WHERE type = 'pure' AND player = playerId AND is_valid = TRUE
          GROUP BY map
    ) AS t
    INNER JOIN map AS m ON m.id = t.map
    ORDER BY m.name ASC;
END ;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 DROP PROCEDURE IF EXISTS `SelectPlayerPbSplits` */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_unicode_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'ONLY_FULL_GROUP_BY,STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
CREATE DEFINER=`root`@`localhost` PROCEDURE `SelectPlayerPbSplits`(IN `mapId` SMALLINT(5) UNSIGNED, IN `playerId` SMALLINT(5) UNSIGNED, IN `topType` VARCHAR(32))
    READS SQL DATA
BEGIN
SELECT sr.split, sr.lap, sr.time
FROM split_run sr
INNER JOIN (
        SELECT r.id, r.time
        FROM run r
        WHERE r.map = mapId AND r.player = playerId AND r.type = topType AND r.is_valid = TRUE
        ORDER BY r.time
        LIMIT 1
    ) AS r on r.id = sr.run
ORDER BY sr.lap, sr.split;
END ;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 DROP PROCEDURE IF EXISTS `SelectPlayerWrPureRuns` */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_unicode_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'ONLY_FULL_GROUP_BY,STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
CREATE DEFINER=`execut4ble`@`%` PROCEDURE `SelectPlayerWrPureRuns`(IN `playerId` SMALLINT(5) UNSIGNED)
    READS SQL DATA
BEGIN
    SELECT m.name, t.bestTime
    FROM (
        SELECT map, MIN(time) AS bestTime
          FROM run
          WHERE type = 'pure' AND is_valid = TRUE
          GROUP BY map
    ) AS t
    INNER JOIN map AS m ON m.id = t.map
    INNER JOIN run AS r ON r.time = t.bestTime AND r.map = t.map
    WHERE r.type = 'pure' AND r.player = playerId AND  r.is_valid = TRUE
    ORDER BY m.name ASC;
END ;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 DROP PROCEDURE IF EXISTS `SelectPlayerWrPureRunsSortTime` */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_unicode_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'ONLY_FULL_GROUP_BY,STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
CREATE DEFINER=`root`@`localhost` PROCEDURE `SelectPlayerWrPureRunsSortTime`(IN `playerId` SMALLINT)
    NO SQL
BEGIN
    SELECT m.name, t.bestTime
    FROM (
        SELECT map, MIN(time) AS bestTime
          FROM run
          WHERE type = 'pure' AND is_valid = TRUE
          GROUP BY map
    ) AS t
    INNER JOIN map AS m ON m.id = t.map
    INNER JOIN run AS r ON r.time = t.bestTime AND r.map = t.map
    WHERE r.type = 'pure' AND r.player = playerId AND  r.is_valid = TRUE
    ORDER BY t.bestTime ASC;
END ;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 DROP PROCEDURE IF EXISTS `SelectPureRunCountTop` */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_unicode_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'ONLY_FULL_GROUP_BY,STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
CREATE DEFINER=`root`@`localhost` PROCEDURE `SelectPureRunCountTop`()
    READS SQL DATA
SELECT p.realname, t.runs, t.avgTime, t.firstRun, t.lastRun
FROM (
	SELECT r.player, COUNT(*) runs, AVG(r.time) avgTime, MIN(r.date) firstRun, MAX(r.date) lastRun
    FROM run r
    WHERE r.type = 'pure' AND r.is_valid = TRUE
    GROUP BY r.player
) AS t
INNER JOIN player p ON p.id = t.player
WHERE p.realname IS NOT NULL
ORDER BY t.runs DESC
LIMIT 200 ;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 DROP PROCEDURE IF EXISTS `SelectPureRunTimeTop` */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_unicode_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'ONLY_FULL_GROUP_BY,STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
CREATE DEFINER=`root`@`localhost` PROCEDURE `SelectPureRunTimeTop`()
    READS SQL DATA
SELECT p.realname, m.name, t.runs, t.pbTime, t.avgTime, t.totalTime, t.firstRun, t.lastRun
FROM (
	SELECT r.player, r.map, COUNT(*) runs, MIN(r.time) pbTime, AVG(r.time) avgTime, SUM(r.time) totalTime, MIN(r.date) firstRun, MAX(r.date) lastRun
    FROM run r
    WHERE r.type = 'pure' AND r.is_valid = TRUE
    GROUP BY r.player, r.map
) AS t
INNER JOIN player p ON p.id = t.player
INNER JOIN map m ON m.id = t.map
WHERE p.realname IS NOT NULL
ORDER BY t.totalTime DESC
LIMIT 200 ;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 DROP PROCEDURE IF EXISTS `SelectWrPureRuns` */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_unicode_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'ONLY_FULL_GROUP_BY,STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
CREATE DEFINER=`execut4ble`@`%` PROCEDURE `SelectWrPureRuns`()
    READS SQL DATA
BEGIN
    SELECT p.unique_id, pn.name AS nickname, m.name AS map_name, r.time
    FROM run r
    INNER JOIN (
        SELECT map, MIN(time) as bestTime
        FROM run
        WHERE type = 'pure' AND is_valid = TRUE
        GROUP BY map
    ) r2 ON r2.map = r.map AND r2.bestTime = r.time
    INNER JOIN map m ON m.id = r.map
    INNER JOIN player p ON p.id = r.player
    INNER JOIN player_name pn ON pn.player = r.player AND pn.date = r.date
    WHERE r.type = 'pure' AND r.is_valid = TRUE
    ORDER BY map_name ASC;
END ;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 DROP PROCEDURE IF EXISTS `SelectWrPureTop` */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_unicode_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'ONLY_FULL_GROUP_BY,STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
CREATE DEFINER=`execut4ble`@`%` PROCEDURE `SelectWrPureTop`()
    READS SQL DATA
BEGIN
    SELECT p.unique_id, p.realname, t.wr_count
    FROM (
        SELECT r.player, COUNT(*) AS wr_count
        FROM run AS r
        INNER JOIN (
            SELECT map, MIN(time) as bestTime
            FROM run
            WHERE type = 'pure' AND is_valid = TRUE
            GROUP BY map
        ) AS r2 ON r2.map = r.map AND r2.bestTime = r.time
        INNER JOIN player p ON p.id = r.player
        WHERE r.type = 'pure' AND r.is_valid = TRUE
        GROUP BY r.player
    ) AS t
    INNER JOIN player AS p ON p.id = t.player
    ORDER BY t.wr_count DESC;
END ;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;

--
-- Final view structure for view `DataForMedalsView`
--

/*!50001 DROP VIEW IF EXISTS `DataForMedalsView`*/;
/*!50001 SET @saved_cs_client          = @@character_set_client */;
/*!50001 SET @saved_cs_results         = @@character_set_results */;
/*!50001 SET @saved_col_connection     = @@collation_connection */;
/*!50001 SET character_set_client      = utf8mb4 */;
/*!50001 SET character_set_results     = utf8mb4 */;
/*!50001 SET collation_connection      = utf8mb4_unicode_ci */;
/*!50001 CREATE ALGORITHM=UNDEFINED */
/*!50013 DEFINER=`root`@`localhost` SQL SECURITY DEFINER */
/*!50001 VIEW `DataForMedalsView` AS select `m`.`name` AS `Map name`,`t`.`wrTime` AS `WR time`,`GetMapTopNRunsAvgTime`(`m`.`id`,'pure',round((`t`.`runs` * 0.05),0)) AS `Best 5% runs avg. time`,(`GetMapTop15SumTime`(`m`.`id`,'pure') / 15) AS `Top 15 avg. time`,`GetMapRankNTime`(`m`.`id`,'pure',10) AS `#10 time`,`GetMapRankNTime`(`m`.`id`,'pure',round((`t2`.`runners` / 2),0)) AS `Mid time`,`t`.`avgTime` AS `Avg. time`,`t`.`totalTime` AS `Total time`,`t`.`runs` AS `Runs`,`t2`.`runners` AS `Runners` from (((select `r`.`map` AS `map`,min(`r`.`time`) AS `wrTime`,avg(`r`.`time`) AS `avgTime`,sum(`r`.`time`) AS `totalTime`,count(0) AS `runs` from `run` `r` where ((`r`.`type` = 'pure') and (`r`.`is_valid` = TRUE)) group by `r`.`map`) `t` join (select `r2`.`map` AS `map`,count(`r2`.`player`) AS `runners` from (select `r3`.`map` AS `map`,`r3`.`player` AS `player` from `run` `r3` where ((`r3`.`type` = 'pure') and (`r3`.`is_valid` = TRUE)) group by `r3`.`map`,`r3`.`player`) `r2` group by `r2`.`map`) `t2` on((`t2`.`map` = `t`.`map`))) join `map` `m` on((`m`.`id` = `t`.`map`))) where (`m`.`is_deprecated` = FALSE) having ((`t`.`runs` > 25) and (`t`.`avgTime` > 10) and (`t`.`totalTime` > 5000) and (`t2`.`runners` > 15)) order by `t`.`totalTime` desc */;
/*!50001 SET character_set_client      = @saved_cs_client */;
/*!50001 SET character_set_results     = @saved_cs_results */;
/*!50001 SET collation_connection      = @saved_col_connection */;

--
-- Final view structure for view `SeasonMapPool`
--

/*!50001 DROP VIEW IF EXISTS `SeasonMapPool`*/;
/*!50001 SET @saved_cs_client          = @@character_set_client */;
/*!50001 SET @saved_cs_results         = @@character_set_results */;
/*!50001 SET @saved_col_connection     = @@collation_connection */;
/*!50001 SET character_set_client      = utf8mb4 */;
/*!50001 SET character_set_results     = utf8mb4 */;
/*!50001 SET collation_connection      = utf8mb4_unicode_ci */;
/*!50001 CREATE ALGORITHM=UNDEFINED */
/*!50013 DEFINER=`root`@`localhost` SQL SECURITY DEFINER */
/*!50001 VIEW `SeasonMapPool` AS select `m`.`name` AS `Map name`,`t`.`wrTime` AS `WR time`,`GetMapTopNRunsAvgTime`(`m`.`id`,'pure',round((`t`.`runs` * 0.05),0)) AS `Best 5% runs avg. time`,(`GetMapTop15SumTime`(`m`.`id`,'pure') / 15) AS `Top 15 avg. time`,`GetMapRankNTime`(`m`.`id`,'pure',10) AS `#10 time`,`GetMapRankNTime`(`m`.`id`,'pure',round((`t2`.`runners` / 2),0)) AS `Mid time`,`t`.`avgTime` AS `Avg. time`,`t`.`totalTime` AS `Total time`,`t`.`runs` AS `Runs`,`t2`.`runners` AS `Runners` from (((select `r`.`map` AS `map`,min(`r`.`time`) AS `wrTime`,avg(`r`.`time`) AS `avgTime`,sum(`r`.`time`) AS `totalTime`,count(0) AS `runs` from `run` `r` where ((`r`.`type` = 'pure') and (`r`.`is_valid` = TRUE)) group by `r`.`map`) `t` join (select `r2`.`map` AS `map`,count(`r2`.`player`) AS `runners` from (select `r3`.`map` AS `map`,`r3`.`player` AS `player` from `run` `r3` where ((`r3`.`type` = 'pure') and (`r3`.`is_valid` = TRUE)) group by `r3`.`map`,`r3`.`player`) `r2` group by `r2`.`map`) `t2` on((`t2`.`map` = `t`.`map`))) join `map` `m` on((`m`.`id` = `t`.`map`))) where (`m`.`is_deprecated` = FALSE) having ((`t`.`runs` > 25) and (`t`.`avgTime` > 8) and (`t`.`wrTime` < 120) and (`t`.`totalTime` > 4000) and (`t2`.`runners` > 5) and (`t`.`runs` > (`t2`.`runners` * 5))) order by `t`.`totalTime` desc */;
/*!50001 SET character_set_client      = @saved_cs_client */;
/*!50001 SET character_set_results     = @saved_cs_results */;
/*!50001 SET collation_connection      = @saved_col_connection */;

--
-- Final view structure for view `SeasonMapPoolExtended`
--

/*!50001 DROP VIEW IF EXISTS `SeasonMapPoolExtended`*/;
/*!50001 SET @saved_cs_client          = @@character_set_client */;
/*!50001 SET @saved_cs_results         = @@character_set_results */;
/*!50001 SET @saved_col_connection     = @@collation_connection */;
/*!50001 SET character_set_client      = utf8mb4 */;
/*!50001 SET character_set_results     = utf8mb4 */;
/*!50001 SET collation_connection      = utf8mb4_unicode_ci */;
/*!50001 CREATE ALGORITHM=UNDEFINED */
/*!50013 DEFINER=`root`@`localhost` SQL SECURITY DEFINER */
/*!50001 VIEW `SeasonMapPoolExtended` AS select `m`.`name` AS `Map name`,`t`.`wrTime` AS `WR time`,`GetMapTopNRunsAvgTime`(`m`.`id`,'pure',round((`t`.`runs` * 0.05),0)) AS `Best 5% runs avg. time`,(`GetMapTop15SumTime`(`m`.`id`,'pure') / 15) AS `Top 15 avg. time`,`GetMapRankNTime`(`m`.`id`,'pure',10) AS `#10 time`,`GetMapRankNTime`(`m`.`id`,'pure',round((`t2`.`runners` / 2),0)) AS `Mid time`,`t`.`avgTime` AS `Avg. time`,`t`.`totalTime` AS `Total time`,`t`.`runs` AS `Runs`,`t2`.`runners` AS `Runners` from (((select `r`.`map` AS `map`,min(`r`.`time`) AS `wrTime`,avg(`r`.`time`) AS `avgTime`,sum(`r`.`time`) AS `totalTime`,count(0) AS `runs` from `run` `r` where ((`r`.`type` = 'pure') and (`r`.`is_valid` = TRUE)) group by `r`.`map`) `t` join (select `r2`.`map` AS `map`,count(`r2`.`player`) AS `runners` from (select `r3`.`map` AS `map`,`r3`.`player` AS `player` from `run` `r3` where ((`r3`.`type` = 'pure') and (`r3`.`is_valid` = TRUE)) group by `r3`.`map`,`r3`.`player`) `r2` group by `r2`.`map`) `t2` on((`t2`.`map` = `t`.`map`))) join `map` `m` on((`m`.`id` = `t`.`map`))) where (`m`.`is_deprecated` = FALSE) having ((`t`.`runs` > 20) and (`t`.`avgTime` > 8) and (`t`.`totalTime` > 3000) and (`t2`.`runners` > 5) and (`t`.`runs` > (`t2`.`runners` * 3))) order by `t`.`totalTime` desc */;
/*!50001 SET character_set_client      = @saved_cs_client */;
/*!50001 SET character_set_results     = @saved_cs_results */;
/*!50001 SET collation_connection      = @saved_col_connection */;

--
-- Final view structure for view `SeasonMapPoolTrendy`
--

/*!50001 DROP VIEW IF EXISTS `SeasonMapPoolTrendy`*/;
/*!50001 SET @saved_cs_client          = @@character_set_client */;
/*!50001 SET @saved_cs_results         = @@character_set_results */;
/*!50001 SET @saved_col_connection     = @@collation_connection */;
/*!50001 SET character_set_client      = utf8mb4 */;
/*!50001 SET character_set_results     = utf8mb4 */;
/*!50001 SET collation_connection      = utf8mb4_unicode_ci */;
/*!50001 CREATE ALGORITHM=UNDEFINED */
/*!50013 DEFINER=`root`@`localhost` SQL SECURITY DEFINER */
/*!50001 VIEW `SeasonMapPoolTrendy` AS select `m`.`name` AS `Map name`,`t`.`bestTime` AS `Best time`,`GetMapTopNRunsAvgTime`(`m`.`id`,'pure',round((`t`.`runs` * 0.05),0)) AS `Best 5% runs avg. time`,(`GetMapTop15SumTime`(`m`.`id`,'pure') / 15) AS `Top 15 avg. time`,`GetMapRankNTime`(`m`.`id`,'pure',10) AS `#10 time`,`GetMapRankNTime`(`m`.`id`,'pure',round((`t2`.`runners` / 2),0)) AS `Mid time`,`t`.`avgTime` AS `Avg. time`,`t`.`totalTime` AS `Total time`,`t`.`runs` AS `Runs`,`t2`.`runners` AS `Runners` from (((select `r`.`map` AS `map`,min(`r`.`time`) AS `bestTime`,avg(`r`.`time`) AS `avgTime`,sum(`r`.`time`) AS `totalTime`,count(0) AS `runs` from `run` `r` where ((`r`.`type` = 'pure') and (`r`.`date` > (now() - interval 180 day)) and (`r`.`is_valid` = TRUE)) group by `r`.`map`) `t` join (select `r2`.`map` AS `map`,count(`r2`.`player`) AS `runners` from (select `r3`.`map` AS `map`,`r3`.`player` AS `player` from `run` `r3` where ((`r3`.`type` = 'pure') and (`r3`.`date` > (now() - interval 180 day)) and (`r3`.`is_valid` = TRUE)) group by `r3`.`map`,`r3`.`player`) `r2` group by `r2`.`map`) `t2` on((`t2`.`map` = `t`.`map`))) join `map` `m` on((`m`.`id` = `t`.`map`))) where (`m`.`is_deprecated` = FALSE) having ((`t`.`runs` > 20) and (`t`.`avgTime` > 8) and (`t`.`totalTime` > 3000)) order by `t`.`totalTime` desc */;
/*!50001 SET character_set_client      = @saved_cs_client */;
/*!50001 SET character_set_results     = @saved_cs_results */;
/*!50001 SET collation_connection      = @saved_col_connection */;

--
-- Final view structure for view `SeasonMapPoolTrendyExtended`
--

/*!50001 DROP VIEW IF EXISTS `SeasonMapPoolTrendyExtended`*/;
/*!50001 SET @saved_cs_client          = @@character_set_client */;
/*!50001 SET @saved_cs_results         = @@character_set_results */;
/*!50001 SET @saved_col_connection     = @@collation_connection */;
/*!50001 SET character_set_client      = utf8mb4 */;
/*!50001 SET character_set_results     = utf8mb4 */;
/*!50001 SET collation_connection      = utf8mb4_unicode_ci */;
/*!50001 CREATE ALGORITHM=UNDEFINED */
/*!50013 DEFINER=`root`@`localhost` SQL SECURITY DEFINER */
/*!50001 VIEW `SeasonMapPoolTrendyExtended` AS select `m`.`name` AS `Map name`,`t`.`bestTime` AS `Best time`,`GetMapTopNRunsAvgTime`(`m`.`id`,'pure',round((`t`.`runs` * 0.05),0)) AS `Best 5% runs avg. time`,(`GetMapTop15SumTime`(`m`.`id`,'pure') / 15) AS `Top 15 avg. time`,`GetMapRankNTime`(`m`.`id`,'pure',10) AS `#10 time`,`GetMapRankNTime`(`m`.`id`,'pure',round((`t2`.`runners` / 2),0)) AS `Mid time`,`t`.`avgTime` AS `Avg. time`,`t`.`totalTime` AS `Total time`,`t`.`runs` AS `Runs`,`t2`.`runners` AS `Runners` from (((select `r`.`map` AS `map`,min(`r`.`time`) AS `bestTime`,avg(`r`.`time`) AS `avgTime`,sum(`r`.`time`) AS `totalTime`,count(0) AS `runs` from `run` `r` where ((`r`.`type` = 'pure') and (`r`.`date` > (now() - interval 180 day)) and (`r`.`is_valid` = TRUE)) group by `r`.`map`) `t` join (select `r2`.`map` AS `map`,count(`r2`.`player`) AS `runners` from (select `r3`.`map` AS `map`,`r3`.`player` AS `player` from `run` `r3` where ((`r3`.`type` = 'pure') and (`r3`.`date` > (now() - interval 180 day)) and (`r3`.`is_valid` = TRUE)) group by `r3`.`map`,`r3`.`player`) `r2` group by `r2`.`map`) `t2` on((`t2`.`map` = `t`.`map`))) join `map` `m` on((`m`.`id` = `t`.`map`))) where (`m`.`is_deprecated` = FALSE) having ((`t`.`runs` > 15) and (`t`.`avgTime` > 7) and (`t`.`totalTime` > 2500)) order by `t`.`totalTime` desc */;
/*!50001 SET character_set_client      = @saved_cs_client */;
/*!50001 SET character_set_results     = @saved_cs_results */;
/*!50001 SET collation_connection      = @saved_col_connection */;
SET @@SESSION.SQL_LOG_BIN = @MYSQLDUMP_TEMP_LOG_BIN;
/*!50112 SET @disable_bulk_load = IF (@is_rocksdb_supported, 'SET SESSION rocksdb_bulk_load = @old_rocksdb_bulk_load', 'SET @dummy_rocksdb_bulk_load = 0') */;
/*!50112 PREPARE s FROM @disable_bulk_load */;
/*!50112 EXECUTE s */;
/*!50112 DEALLOCATE PREPARE s */;
/*!40103 SET TIME_ZONE=@OLD_TIME_ZONE */;

/*!40101 SET SQL_MODE=@OLD_SQL_MODE */;
/*!40014 SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS */;
/*!40014 SET UNIQUE_CHECKS=@OLD_UNIQUE_CHECKS */;
/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
/*!40111 SET SQL_NOTES=@OLD_SQL_NOTES */;

-- Dump completed on 2024-07-10 19:25:03
