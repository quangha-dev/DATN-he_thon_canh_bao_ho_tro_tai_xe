-- MySQL dump 10.13  Distrib 8.4.10, for Linux (x86_64)
--
-- Host: localhost    Database: safefleet
-- ------------------------------------------------------
-- Server version	8.4.10

/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!50503 SET NAMES utf8mb4 */;
/*!40103 SET @OLD_TIME_ZONE=@@TIME_ZONE */;
/*!40103 SET TIME_ZONE='+00:00' */;
/*!40014 SET @OLD_UNIQUE_CHECKS=@@UNIQUE_CHECKS, UNIQUE_CHECKS=0 */;
/*!40014 SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0 */;
/*!40101 SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='NO_AUTO_VALUE_ON_ZERO' */;
/*!40111 SET @OLD_SQL_NOTES=@@SQL_NOTES, SQL_NOTES=0 */;

--
-- Table structure for table `agent_commands`
--

DROP TABLE IF EXISTS `agent_commands`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `agent_commands` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `user_id` bigint NOT NULL,
  `driver_id` bigint DEFAULT NULL,
  `trip_id` bigint DEFAULT NULL,
  `command_type` varchar(30) COLLATE utf8mb4_unicode_ci NOT NULL,
  `transcript` varchar(1000) COLLATE utf8mb4_unicode_ci NOT NULL,
  `normalized_command` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `interpreted_intent` varchar(40) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `confidence` double DEFAULT NULL,
  `requires_confirmation` tinyint(1) NOT NULL DEFAULT '0',
  `classification_source` varchar(30) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `status` varchar(30) COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'RECEIVED',
  `response_text` varchar(1000) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `executed_reference_type` varchar(40) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `executed_reference_id` bigint DEFAULT NULL,
  `created_at` datetime(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  `updated_at` datetime(6) DEFAULT NULL,
  `deleted` tinyint(1) NOT NULL DEFAULT '0',
  PRIMARY KEY (`id`),
  KEY `fk_agent_command_trip` (`trip_id`),
  KEY `idx_agent_user_created` (`user_id`,`created_at`),
  KEY `idx_agent_driver_created` (`driver_id`,`created_at`),
  KEY `idx_agent_intent_status` (`interpreted_intent`,`status`),
  CONSTRAINT `fk_agent_command_driver` FOREIGN KEY (`driver_id`) REFERENCES `drivers` (`id`),
  CONSTRAINT `fk_agent_command_trip` FOREIGN KEY (`trip_id`) REFERENCES `trips` (`id`),
  CONSTRAINT `fk_agent_command_user` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `agent_commands`
--

LOCK TABLES `agent_commands` WRITE;
/*!40000 ALTER TABLE `agent_commands` DISABLE KEYS */;
/*!40000 ALTER TABLE `agent_commands` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `audit_logs`
--

DROP TABLE IF EXISTS `audit_logs`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `audit_logs` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `actor_id` bigint DEFAULT NULL,
  `action` varchar(120) COLLATE utf8mb4_unicode_ci NOT NULL,
  `target_type` varchar(80) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `target_id` bigint DEFAULT NULL,
  `ip_address` varchar(80) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `user_agent` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `created_at` datetime(6) NOT NULL,
  PRIMARY KEY (`id`),
  KEY `idx_audit_logs_actor_created` (`actor_id`,`created_at`),
  KEY `idx_audit_logs_target` (`target_type`,`target_id`),
  CONSTRAINT `fk_audit_logs_actor` FOREIGN KEY (`actor_id`) REFERENCES `users` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `audit_logs`
--

LOCK TABLES `audit_logs` WRITE;
/*!40000 ALTER TABLE `audit_logs` DISABLE KEYS */;
/*!40000 ALTER TABLE `audit_logs` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `device_connection_logs`
--

DROP TABLE IF EXISTS `device_connection_logs`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `device_connection_logs` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `device_id` bigint NOT NULL,
  `status` varchar(30) COLLATE utf8mb4_unicode_ci NOT NULL,
  `lat` double DEFAULT NULL,
  `lng` double DEFAULT NULL,
  `note` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `created_at` datetime(6) NOT NULL,
  PRIMARY KEY (`id`),
  KEY `idx_device_logs_device_created` (`device_id`,`created_at`),
  CONSTRAINT `fk_device_logs_device` FOREIGN KEY (`device_id`) REFERENCES `devices` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `device_connection_logs`
--

LOCK TABLES `device_connection_logs` WRITE;
/*!40000 ALTER TABLE `device_connection_logs` DISABLE KEYS */;
/*!40000 ALTER TABLE `device_connection_logs` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `devices`
--

DROP TABLE IF EXISTS `devices`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `devices` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `device_code` varchar(50) COLLATE utf8mb4_unicode_ci NOT NULL,
  `name` varchar(120) COLLATE utf8mb4_unicode_ci NOT NULL,
  `type` varchar(40) COLLATE utf8mb4_unicode_ci NOT NULL,
  `status` varchar(30) COLLATE utf8mb4_unicode_ci NOT NULL,
  `vehicle_id` bigint DEFAULT NULL,
  `phone` varchar(20) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `serial_number` varchar(80) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `firmware_version` varchar(40) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `last_seen_at` datetime(6) DEFAULT NULL,
  `created_at` datetime(6) NOT NULL,
  `updated_at` datetime(6) DEFAULT NULL,
  `deleted` tinyint(1) NOT NULL DEFAULT '0',
  PRIMARY KEY (`id`),
  UNIQUE KEY `device_code` (`device_code`),
  KEY `idx_devices_type_status` (`type`,`status`),
  KEY `idx_devices_vehicle` (`vehicle_id`),
  CONSTRAINT `fk_devices_vehicle` FOREIGN KEY (`vehicle_id`) REFERENCES `vehicles` (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=11 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `devices`
--

LOCK TABLES `devices` WRITE;
/*!40000 ALTER TABLE `devices` DISABLE KEYS */;
INSERT INTO `devices` VALUES (1,'DEV-001','Thiet bi 001','GPS_TRACKER','ONLINE',1,NULL,'SN-HN-00001','1.0.1','2026-07-27 00:02:48.024796','2026-07-27 00:05:48.025145','2026-07-27 00:05:48.148808',0),(2,'DEV-002','Thiet bi 002','GPS_TRACKER','ONLINE',2,NULL,'SN-HN-00002','1.0.2','2026-07-26 23:59:48.027768','2026-07-27 00:05:48.027862','2026-07-27 00:05:48.148834',0),(3,'DEV-003','Thiet bi 003','GPS_TRACKER','ONLINE',3,NULL,'SN-HN-00003','1.0.3','2026-07-26 23:56:48.028947','2026-07-27 00:05:48.029023','2026-07-27 00:05:48.148853',0),(4,'DEV-004','Thiet bi 004','GPS_TRACKER','ONLINE',4,NULL,'SN-HN-00004','1.0.4','2026-07-26 23:53:48.030052','2026-07-27 00:05:48.030130','2026-07-27 00:05:48.148870',0),(5,'DEV-005','Thiet bi 005','GPS_TRACKER','ONLINE',5,NULL,'SN-HN-00005','1.0.5','2026-07-26 23:50:48.031082','2026-07-27 00:05:48.031157','2026-07-27 00:05:48.148888',0),(6,'DEV-006','Thiet bi 006','GPS_TRACKER','ONLINE',6,NULL,'SN-HN-00006','1.0.6','2026-07-26 23:47:48.032138','2026-07-27 00:05:48.032274','2026-07-27 00:05:48.148902',0),(7,'DEV-007','Thiet bi 007','CABIN_CAMERA','ONLINE',NULL,NULL,'SN-HN-00007','1.0.7','2026-07-26 23:44:48.033259','2026-07-27 00:05:48.033351','2026-07-27 00:05:48.033351',0),(8,'DEV-008','Thiet bi 008','CABIN_CAMERA','ONLINE',NULL,NULL,'SN-HN-00008','1.0.8','2026-07-26 23:41:48.034696','2026-07-27 00:05:48.034817','2026-07-27 00:05:48.034817',0),(9,'DEV-009','Thiet bi 009','DRIVER_PHONE','OFFLINE',NULL,NULL,'SN-HN-00009','1.0.9',NULL,'2026-07-27 00:05:48.036185','2026-07-27 00:05:48.036185',0),(10,'DEV-010','Thiet bi 010','DRIVER_PHONE','OFFLINE',NULL,NULL,'SN-HN-00010','1.0.10',NULL,'2026-07-27 00:05:48.037078','2026-07-27 00:05:48.037078',0);
/*!40000 ALTER TABLE `devices` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `driver_work_logs`
--

DROP TABLE IF EXISTS `driver_work_logs`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `driver_work_logs` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `driver_id` bigint NOT NULL,
  `trip_id` bigint DEFAULT NULL,
  `work_date` date NOT NULL,
  `driving_minutes` int NOT NULL DEFAULT '0',
  `rest_minutes` int NOT NULL DEFAULT '0',
  `note` varchar(500) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `created_at` datetime(6) NOT NULL,
  `updated_at` datetime(6) DEFAULT NULL,
  `deleted` tinyint(1) NOT NULL DEFAULT '0',
  PRIMARY KEY (`id`),
  KEY `fk_driver_work_logs_trip` (`trip_id`),
  KEY `idx_driver_work_logs_driver_date` (`driver_id`,`work_date`),
  CONSTRAINT `fk_driver_work_logs_driver` FOREIGN KEY (`driver_id`) REFERENCES `drivers` (`id`),
  CONSTRAINT `fk_driver_work_logs_trip` FOREIGN KEY (`trip_id`) REFERENCES `trips` (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=3 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `driver_work_logs`
--

LOCK TABLES `driver_work_logs` WRITE;
/*!40000 ALTER TABLE `driver_work_logs` DISABLE KEYS */;
INSERT INTO `driver_work_logs` VALUES (1,8,8,'2026-07-27',0,0,NULL,'2026-07-27 00:26:18.415975','2026-07-27 00:26:18.415975',0),(2,1,11,'2026-07-27',0,0,NULL,'2026-07-27 03:23:15.735158','2026-07-27 03:23:15.735158',0);
/*!40000 ALTER TABLE `driver_work_logs` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `drivers`
--

DROP TABLE IF EXISTS `drivers`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `drivers` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `user_id` bigint DEFAULT NULL,
  `full_name` varchar(150) COLLATE utf8mb4_unicode_ci NOT NULL,
  `phone` varchar(20) COLLATE utf8mb4_unicode_ci NOT NULL,
  `email` varchar(120) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `address` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `license_number` varchar(50) COLLATE utf8mb4_unicode_ci NOT NULL,
  `license_class` varchar(20) COLLATE utf8mb4_unicode_ci NOT NULL,
  `license_expired_at` date NOT NULL,
  `status` varchar(30) COLLATE utf8mb4_unicode_ci NOT NULL,
  `current_vehicle_id` bigint DEFAULT NULL,
  `safety_score` int NOT NULL DEFAULT '100',
  `driving_time_today_minutes` int NOT NULL DEFAULT '0',
  `continuous_driving_minutes` int NOT NULL DEFAULT '0',
  `total_trips` int NOT NULL DEFAULT '0',
  `total_alerts` int NOT NULL DEFAULT '0',
  `created_at` datetime(6) NOT NULL,
  `updated_at` datetime(6) DEFAULT NULL,
  `deleted` tinyint(1) NOT NULL DEFAULT '0',
  PRIMARY KEY (`id`),
  UNIQUE KEY `license_number` (`license_number`),
  UNIQUE KEY `user_id` (`user_id`),
  KEY `idx_drivers_status` (`status`),
  KEY `idx_drivers_license_class` (`license_class`),
  KEY `idx_drivers_safety_score` (`safety_score`),
  KEY `fk_drivers_current_vehicle` (`current_vehicle_id`),
  CONSTRAINT `fk_drivers_current_vehicle` FOREIGN KEY (`current_vehicle_id`) REFERENCES `vehicles` (`id`),
  CONSTRAINT `fk_drivers_user` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=16 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `drivers`
--

LOCK TABLES `drivers` WRITE;
/*!40000 ALTER TABLE `drivers` DISABLE KEYS */;
INSERT INTO `drivers` VALUES (1,6,'Nguyen Van An','0988000001','driver01@safefleet.vn','Ha Dong','HN-B2-00001','C','2028-07-27','AVAILABLE',1,80,0,0,1,3,'2026-07-27 00:05:47.100909','2026-07-27 03:23:15.744318',0),(2,7,'Tran Minh Duc','0988000002','driver02@safefleet.vn','Cau Giay','HN-B2-00002','B2','2028-08-27','AVAILABLE',2,91,12,30,0,1,'2026-07-27 00:05:47.172705','2026-07-27 00:05:48.147438',0),(3,8,'Le Quang Huy','0988000003','driver03@safefleet.vn','My Dinh','HN-B2-00003','B2','2028-09-27','AVAILABLE',3,88,24,60,0,1,'2026-07-27 00:05:47.240300','2026-07-27 00:05:48.147496',0),(4,9,'Pham Tuan Anh','0988000004','driver04@safefleet.vn','Phu Dien','HN-B2-00004','B2','2028-10-27','AVAILABLE',4,85,36,90,0,1,'2026-07-27 00:05:47.305708','2026-07-27 00:05:48.147526',0),(5,10,'Do Van Nam','0988000005','driver05@safefleet.vn','Ho Tung Mau','HN-B2-00005','C','2028-11-27','AVAILABLE',5,82,48,120,0,1,'2026-07-27 00:05:47.371865','2026-07-27 00:05:48.148094',0),(6,11,'Hoang Manh Cuong','0988000006','driver06@safefleet.vn','Ha Dong','HN-B2-00006','B2','2028-12-27','AVAILABLE',6,79,60,0,0,1,'2026-07-27 00:05:47.438445','2026-07-27 00:05:48.148131',0),(7,12,'Vu Thanh Long','0988000007','driver07@safefleet.vn','Cau Giay','HN-B2-00007','B2','2029-01-27','AVAILABLE',7,76,72,30,0,1,'2026-07-27 00:05:47.505006','2026-07-27 00:05:48.148368',0),(8,13,'Bui Hai Dang','0988000008','driver08@safefleet.vn','My Dinh','HN-B2-00008','B2','2029-02-27','AVAILABLE',8,66,84,0,1,2,'2026-07-27 00:05:47.567198','2026-07-27 00:26:18.419989',0),(9,14,'Dang Quoc Viet','0988000009','driver09@safefleet.vn','Phu Dien','HN-B2-00009','C','2029-03-27','AVAILABLE',9,70,96,90,0,1,'2026-07-27 00:05:47.631629','2026-07-27 00:05:48.148520',0),(10,15,'Phan Van Son','0988000010','driver10@safefleet.vn','Ho Tung Mau','HN-B2-00010','B2','2029-04-27','AVAILABLE',10,67,108,120,0,1,'2026-07-27 00:05:47.698783','2026-07-27 00:05:48.148559',0),(11,16,'Nguyen Duc Thang','0988000011','driver11@safefleet.vn','Ha Dong','HN-B2-00011','B2','2029-05-27','AVAILABLE',11,64,120,0,0,1,'2026-07-27 00:05:47.764175','2026-07-27 00:05:48.148587',0),(12,17,'Tran Bao Khanh','0988000012','driver12@safefleet.vn','Cau Giay','HN-B2-00012','B2','2029-06-27','AVAILABLE',12,61,132,30,0,1,'2026-07-27 00:05:47.829260','2026-07-27 00:05:48.148650',0),(13,18,'Le Thanh Tung','0988000013','driver13@safefleet.vn','My Dinh','HN-B2-00013','C','2029-07-27','AVAILABLE',13,58,144,60,0,1,'2026-07-27 00:05:47.893142','2026-07-27 00:05:48.148696',0),(14,19,'Pham Dinh Khoa','0988000014','driver14@safefleet.vn','Phu Dien','HN-B2-00014','B2','2029-08-27','HIGH_RISK',14,55,156,90,0,1,'2026-07-27 00:05:47.956994','2026-07-27 00:05:48.148722',0),(15,20,'Do Minh Quan','0988000015','driver15@safefleet.vn','Ho Tung Mau','HN-B2-00015','B2','2029-09-27','AVAILABLE',15,52,168,120,0,1,'2026-07-27 00:05:48.022841','2026-07-27 00:05:48.148748',0);
/*!40000 ALTER TABLE `drivers` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `driving_sessions`
--

DROP TABLE IF EXISTS `driving_sessions`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `driving_sessions` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `driver_id` bigint NOT NULL,
  `vehicle_id` bigint DEFAULT NULL,
  `trip_id` bigint DEFAULT NULL,
  `status` varchar(30) COLLATE utf8mb4_unicode_ci NOT NULL,
  `started_at` datetime(6) NOT NULL,
  `paused_at` datetime(6) DEFAULT NULL,
  `resumed_at` datetime(6) DEFAULT NULL,
  `ended_at` datetime(6) DEFAULT NULL,
  `continuous_minutes` int NOT NULL DEFAULT '0',
  `total_minutes` int NOT NULL DEFAULT '0',
  `over_driving_alert_created` tinyint(1) NOT NULL DEFAULT '0',
  `created_at` datetime(6) NOT NULL,
  `updated_at` datetime(6) DEFAULT NULL,
  `deleted` tinyint(1) NOT NULL DEFAULT '0',
  PRIMARY KEY (`id`),
  KEY `fk_driving_sessions_vehicle` (`vehicle_id`),
  KEY `fk_driving_sessions_trip` (`trip_id`),
  KEY `idx_driving_sessions_driver_status` (`driver_id`,`status`),
  CONSTRAINT `fk_driving_sessions_driver` FOREIGN KEY (`driver_id`) REFERENCES `drivers` (`id`),
  CONSTRAINT `fk_driving_sessions_trip` FOREIGN KEY (`trip_id`) REFERENCES `trips` (`id`),
  CONSTRAINT `fk_driving_sessions_vehicle` FOREIGN KEY (`vehicle_id`) REFERENCES `vehicles` (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=3 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `driving_sessions`
--

LOCK TABLES `driving_sessions` WRITE;
/*!40000 ALTER TABLE `driving_sessions` DISABLE KEYS */;
INSERT INTO `driving_sessions` VALUES (1,8,8,8,'FINISHED','2026-07-27 00:26:18.252436',NULL,'2026-07-27 00:26:18.409582','2026-07-27 00:26:18.409610',0,0,0,'2026-07-27 00:26:18.252834','2026-07-27 00:26:18.420484',0),(2,1,1,11,'FINISHED','2026-07-27 03:23:15.527260',NULL,'2026-07-27 03:23:15.722382','2026-07-27 03:23:15.722538',0,0,0,'2026-07-27 03:23:15.528220','2026-07-27 03:23:15.744831',0);
/*!40000 ALTER TABLE `driving_sessions` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `flood_reports`
--

DROP TABLE IF EXISTS `flood_reports`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `flood_reports` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `lat` double NOT NULL,
  `lng` double NOT NULL,
  `address` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `severity` varchar(30) COLLATE utf8mb4_unicode_ci NOT NULL,
  `source` varchar(40) COLLATE utf8mb4_unicode_ci NOT NULL,
  `reported_by_driver_id` bigint DEFAULT NULL,
  `image_url` varchar(500) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `confidence` double DEFAULT NULL,
  `status` varchar(30) COLLATE utf8mb4_unicode_ci NOT NULL,
  `verified_by` bigint DEFAULT NULL,
  `verified_at` datetime(6) DEFAULT NULL,
  `expired_at` datetime(6) DEFAULT NULL,
  `created_at` datetime(6) NOT NULL,
  `updated_at` datetime(6) DEFAULT NULL,
  `deleted` tinyint(1) NOT NULL DEFAULT '0',
  `client_event_id` varchar(100) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `sync_batch_id` bigint DEFAULT NULL,
  `received_at` datetime(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_flood_driver_client_event` (`reported_by_driver_id`,`client_event_id`),
  KEY `fk_flood_verified_by` (`verified_by`),
  KEY `idx_flood_status_severity` (`status`,`severity`),
  KEY `idx_flood_location` (`lat`,`lng`),
  KEY `fk_flood_sync_batch` (`sync_batch_id`),
  KEY `idx_flood_received_at` (`received_at`),
  CONSTRAINT `fk_flood_reported_by_driver` FOREIGN KEY (`reported_by_driver_id`) REFERENCES `drivers` (`id`),
  CONSTRAINT `fk_flood_sync_batch` FOREIGN KEY (`sync_batch_id`) REFERENCES `sync_batches` (`id`),
  CONSTRAINT `fk_flood_verified_by` FOREIGN KEY (`verified_by`) REFERENCES `users` (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=12 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `flood_reports`
--

LOCK TABLES `flood_reports` WRITE;
/*!40000 ALTER TABLE `flood_reports` DISABLE KEYS */;
INSERT INTO `flood_reports` VALUES (1,20.9718,105.779,'[DEMO] Ha Dong','BLOCKED','MANUAL',NULL,'https://demo.safefleet.vn/flood/001.jpg',0.55,'EXPIRED',3,'2026-07-27 00:05:48.127757','2026-07-27 03:05:48.127765','2026-07-27 00:05:48.128429','2026-07-27 03:06:06.933726',0,NULL,NULL,'2026-07-27 00:05:48.129497'),(2,21.0365,105.7909,'[DEMO] Cau Giay','MEDIUM','MANUAL',NULL,'https://demo.safefleet.vn/flood/002.jpg',0.5900000000000001,'EXPIRED',3,'2026-07-26 23:05:48.130477','2026-07-27 03:05:48.130485','2026-07-27 00:05:48.130590','2026-07-27 03:06:06.933726',0,NULL,NULL,'2026-07-27 00:05:48.131149'),(3,21.0281,105.7782,'[DEMO] My Dinh','MEDIUM','MANUAL',NULL,'https://demo.safefleet.vn/flood/003.jpg',0.63,'EXPIRED',3,'2026-07-26 22:05:48.131866','2026-07-27 03:05:48.131872','2026-07-27 00:05:48.131944','2026-07-27 03:06:06.933726',0,NULL,NULL,'2026-07-27 00:05:48.132345'),(4,20.9906,105.8052,'[DEMO] Nguyen Trai','HIGH','MANUAL',NULL,'https://demo.safefleet.vn/flood/004.jpg',0.67,'EXPIRED',3,'2026-07-26 21:05:48.132748','2026-07-27 03:05:48.132753','2026-07-27 00:05:48.132817','2026-07-27 03:06:06.933726',0,NULL,NULL,'2026-07-27 00:05:48.133168'),(5,21.0121,105.7625,'[DEMO] Dai lo Thang Long','BLOCKED','MANUAL',NULL,'https://demo.safefleet.vn/flood/005.jpg',0.7100000000000001,'EXPIRED',NULL,NULL,'2026-07-27 03:05:48.133654','2026-07-27 00:05:48.133730','2026-07-27 03:06:06.933726',0,NULL,NULL,'2026-07-27 00:05:48.134883'),(6,21.0526,105.735,'[DEMO] Kieu Mai','MEDIUM','MANUAL',NULL,'https://demo.safefleet.vn/flood/006.jpg',0.75,'EXPIRED',NULL,NULL,'2026-07-27 03:05:48.135388','2026-07-27 00:05:48.135471','2026-07-27 03:06:06.933726',0,NULL,NULL,'2026-07-27 00:05:48.135962'),(7,21.0383,105.7754,'[DEMO] Phu Dien','HIGH','MANUAL',NULL,'https://demo.safefleet.vn/flood/007.jpg',0.79,'EXPIRED',NULL,NULL,'2026-07-27 03:05:48.136513','2026-07-27 00:05:48.136585','2026-07-27 03:06:06.933726',0,NULL,NULL,'2026-07-27 00:05:48.137253'),(8,21.039,105.7462,'[DEMO] Ho Tung Mau','MEDIUM','MANUAL',NULL,'https://demo.safefleet.vn/flood/008.jpg',0.8300000000000001,'EXPIRED',NULL,NULL,'2026-07-27 03:05:48.137716','2026-07-27 00:05:48.137829','2026-07-27 03:06:06.933726',0,NULL,NULL,'2026-07-27 00:05:48.138191'),(9,21.0387,105.7467,'[E2E] Diem ngap test Ho Tung Mau','HIGH','DRIVER_REPORT',8,NULL,0.55,'EXPIRED',NULL,NULL,'2026-07-27 03:07:35.030305','2026-07-27 00:07:35.038912','2026-07-27 03:08:09.157113',0,NULL,NULL,'2026-07-27 00:07:35.039697'),(10,21.0321,105.8123,'Docker flood test Hanoi','HIGH','DRIVER_REPORT',1,NULL,0.45,'EXPIRED',NULL,NULL,'2026-07-27 06:15:53.619169','2026-07-27 03:15:53.857069','2026-07-27 06:16:02.210393',0,'docker-flood-debug-2d54c34281824da89c8c878a080e4ea9',NULL,'2026-07-27 03:15:54.043570'),(11,21.0321,105.8123,'Docker flood idempotency Hanoi','HIGH','DRIVER_REPORT',1,NULL,0.55,'EXPIRED',NULL,NULL,'2026-07-27 06:21:46.073762','2026-07-27 03:21:46.112063','2026-07-27 06:22:02.210905',0,'docker-flood-2b4e3edac56c4527a42788d19ba98b10',NULL,'2026-07-27 03:21:46.073710');
/*!40000 ALTER TABLE `flood_reports` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `flyway_schema_history`
--

DROP TABLE IF EXISTS `flyway_schema_history`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `flyway_schema_history` (
  `installed_rank` int NOT NULL,
  `version` varchar(50) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `description` varchar(200) COLLATE utf8mb4_unicode_ci NOT NULL,
  `type` varchar(20) COLLATE utf8mb4_unicode_ci NOT NULL,
  `script` varchar(1000) COLLATE utf8mb4_unicode_ci NOT NULL,
  `checksum` int DEFAULT NULL,
  `installed_by` varchar(100) COLLATE utf8mb4_unicode_ci NOT NULL,
  `installed_on` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `execution_time` int NOT NULL,
  `success` tinyint(1) NOT NULL,
  PRIMARY KEY (`installed_rank`),
  KEY `flyway_schema_history_s_idx` (`success`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `flyway_schema_history`
--

LOCK TABLES `flyway_schema_history` WRITE;
/*!40000 ALTER TABLE `flyway_schema_history` DISABLE KEYS */;
INSERT INTO `flyway_schema_history` VALUES (1,'1','init schema','SQL','V1__init_schema.sql',-1187998027,'safefleet','2026-07-26 16:59:54',1998,1),(2,'2','seed reference data','SQL','V2__seed_reference_data.sql',-1671001202,'safefleet','2026-07-26 16:59:54',3,1),(3,'3','add mobile driver app support','SQL','V3__add_mobile_driver_app_support.sql',1626901806,'safefleet','2026-07-26 16:59:54',140,1),(4,'4','offline navigation evidence and push','SQL','V4__offline_navigation_evidence_and_push.sql',-1098610819,'safefleet','2026-07-26 16:59:56',1632,1),(5,'5','navigation scoring and batch ack','SQL','V5__navigation_scoring_and_batch_ack.sql',963989075,'safefleet','2026-07-26 17:43:13',503,1),(6,'6','mobile workflow idempotency','SQL','V6__mobile_workflow_idempotency.sql',2017730371,'safefleet','2026-07-26 20:10:24',176,1),(7,'7','agent intent confirmation','SQL','V7__agent_intent_confirmation.sql',-2080680239,'safefleet','2026-07-27 02:54:52',175,1);
/*!40000 ALTER TABLE `flyway_schema_history` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `idempotency_records`
--

DROP TABLE IF EXISTS `idempotency_records`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `idempotency_records` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `user_id` bigint NOT NULL,
  `idempotency_key` varchar(120) COLLATE utf8mb4_unicode_ci NOT NULL,
  `request_method` varchar(10) COLLATE utf8mb4_unicode_ci NOT NULL,
  `request_path` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL,
  `request_hash` char(64) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `response_status` int NOT NULL,
  `response_body` json DEFAULT NULL,
  `created_at` datetime(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  `expires_at` datetime(6) NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_idempotency_user_key` (`user_id`,`idempotency_key`),
  KEY `idx_idempotency_expires` (`expires_at`),
  CONSTRAINT `fk_idempotency_records_user` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `idempotency_records`
--

LOCK TABLES `idempotency_records` WRITE;
/*!40000 ALTER TABLE `idempotency_records` DISABLE KEYS */;
/*!40000 ALTER TABLE `idempotency_records` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `incident_timelines`
--

DROP TABLE IF EXISTS `incident_timelines`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `incident_timelines` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `incident_id` bigint NOT NULL,
  `action` varchar(80) COLLATE utf8mb4_unicode_ci NOT NULL,
  `actor_id` bigint DEFAULT NULL,
  `note` varchar(500) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `created_at` datetime(6) NOT NULL,
  PRIMARY KEY (`id`),
  KEY `fk_incident_timelines_actor` (`actor_id`),
  KEY `idx_incident_timelines_incident_created` (`incident_id`,`created_at`),
  CONSTRAINT `fk_incident_timelines_actor` FOREIGN KEY (`actor_id`) REFERENCES `users` (`id`),
  CONSTRAINT `fk_incident_timelines_incident` FOREIGN KEY (`incident_id`) REFERENCES `incidents` (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=4 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `incident_timelines`
--

LOCK TABLES `incident_timelines` WRITE;
/*!40000 ALTER TABLE `incident_timelines` DISABLE KEYS */;
INSERT INTO `incident_timelines` VALUES (1,6,'SOS_CREATED',13,'SOS submitted from driver app','2026-07-27 00:07:35.121612'),(2,7,'SOS_CREATED',6,'SOS submitted from driver app','2026-07-27 02:07:39.692640'),(3,7,'ACCEPTED',1,'Incident accepted','2026-07-27 02:07:39.883440');
/*!40000 ALTER TABLE `incident_timelines` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `incidents`
--

DROP TABLE IF EXISTS `incidents`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `incidents` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `incident_code` varchar(50) COLLATE utf8mb4_unicode_ci NOT NULL,
  `type` varchar(40) COLLATE utf8mb4_unicode_ci NOT NULL,
  `severity` varchar(30) COLLATE utf8mb4_unicode_ci NOT NULL,
  `vehicle_id` bigint DEFAULT NULL,
  `driver_id` bigint DEFAULT NULL,
  `trip_id` bigint DEFAULT NULL,
  `lat` double DEFAULT NULL,
  `lng` double DEFAULT NULL,
  `description` varchar(1000) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `status` varchar(30) COLLATE utf8mb4_unicode_ci NOT NULL,
  `assigned_to` bigint DEFAULT NULL,
  `accepted_at` datetime(6) DEFAULT NULL,
  `resolved_at` datetime(6) DEFAULT NULL,
  `created_at` datetime(6) NOT NULL,
  `updated_at` datetime(6) DEFAULT NULL,
  `deleted` tinyint(1) NOT NULL DEFAULT '0',
  `client_event_id` varchar(100) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `sync_batch_id` bigint DEFAULT NULL,
  `received_at` datetime(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  PRIMARY KEY (`id`),
  UNIQUE KEY `incident_code` (`incident_code`),
  UNIQUE KEY `uk_incident_driver_client_event` (`driver_id`,`client_event_id`),
  KEY `fk_incidents_trip` (`trip_id`),
  KEY `fk_incidents_assigned_to` (`assigned_to`),
  KEY `idx_incidents_status_severity` (`status`,`severity`),
  KEY `idx_incidents_vehicle_created` (`vehicle_id`,`created_at`),
  KEY `fk_incidents_sync_batch` (`sync_batch_id`),
  KEY `idx_incidents_received_at` (`received_at`),
  CONSTRAINT `fk_incidents_assigned_to` FOREIGN KEY (`assigned_to`) REFERENCES `users` (`id`),
  CONSTRAINT `fk_incidents_driver` FOREIGN KEY (`driver_id`) REFERENCES `drivers` (`id`),
  CONSTRAINT `fk_incidents_sync_batch` FOREIGN KEY (`sync_batch_id`) REFERENCES `sync_batches` (`id`),
  CONSTRAINT `fk_incidents_trip` FOREIGN KEY (`trip_id`) REFERENCES `trips` (`id`),
  CONSTRAINT `fk_incidents_vehicle` FOREIGN KEY (`vehicle_id`) REFERENCES `vehicles` (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=8 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `incidents`
--

LOCK TABLES `incidents` WRITE;
/*!40000 ALTER TABLE `incidents` DISABLE KEYS */;
INSERT INTO `incidents` VALUES (1,'INC-DEMO-001','SOS','CRITICAL',1,1,NULL,20.9719,105.7788,'Demo incident near Ha Dong','OPEN',NULL,NULL,NULL,'2026-07-27 00:05:48.119185','2026-07-27 00:05:48.119185',0,NULL,NULL,'2026-07-27 00:05:48.119961'),(2,'INC-DEMO-002','ACCIDENT','CRITICAL',2,2,NULL,21.0362,105.7906,'Demo incident near Cau Giay','PROCESSING',5,NULL,NULL,'2026-07-27 00:05:48.122276','2026-07-27 00:05:48.122276',0,NULL,NULL,'2026-07-27 00:05:48.122967'),(3,'INC-DEMO-003','VEHICLE_BREAKDOWN','HIGH',3,3,NULL,21.0285,105.7784,'Demo incident near My Dinh','PROCESSING',5,NULL,NULL,'2026-07-27 00:05:48.123840','2026-07-27 00:05:48.123840',0,NULL,NULL,'2026-07-27 00:05:48.124501'),(4,'INC-DEMO-004','GPS_LOST','HIGH',4,4,NULL,20.9902,105.8057,'Demo incident near Nguyen Trai','PROCESSING',5,NULL,NULL,'2026-07-27 00:05:48.125310','2026-07-27 00:05:48.125310',0,NULL,NULL,'2026-07-27 00:05:48.125798'),(5,'INC-DEMO-005','FLOOD_STUCK','HIGH',5,5,NULL,21.0123,105.7621,'Demo incident near Pham Van Dong','PROCESSING',5,NULL,NULL,'2026-07-27 00:05:48.126455','2026-07-27 00:05:48.126455',0,NULL,NULL,'2026-07-27 00:05:48.126969'),(6,'SOS-20260727000735-3319','SOS','CRITICAL',8,8,8,21.03855,105.74645,'[E2E] SOS integration verification','OPEN',NULL,NULL,NULL,'2026-07-27 00:07:35.120365','2026-07-27 00:07:35.120365',0,NULL,NULL,'2026-07-27 00:07:35.120844'),(7,'SOS-20260727020739-5353','SOS','CRITICAL',1,1,NULL,21.0285,105.8542,'Docker real API SOS','ACCEPTED',NULL,'2026-07-27 02:07:39.883418',NULL,'2026-07-27 02:07:39.685431','2026-07-27 02:07:39.895547',0,'docker-sos-1785092858727',NULL,'2026-07-27 02:07:39.684431');
/*!40000 ALTER TABLE `incidents` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `maintenance_orders`
--

DROP TABLE IF EXISTS `maintenance_orders`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `maintenance_orders` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `maintenance_code` varchar(50) COLLATE utf8mb4_unicode_ci NOT NULL,
  `vehicle_id` bigint NOT NULL,
  `type` varchar(30) COLLATE utf8mb4_unicode_ci NOT NULL,
  `title` varchar(150) COLLATE utf8mb4_unicode_ci NOT NULL,
  `description` varchar(1000) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `scheduled_date` date DEFAULT NULL,
  `completed_date` date DEFAULT NULL,
  `cost` decimal(12,2) DEFAULT NULL,
  `status` varchar(30) COLLATE utf8mb4_unicode_ci NOT NULL,
  `priority` varchar(30) COLLATE utf8mb4_unicode_ci NOT NULL,
  `assigned_to` bigint DEFAULT NULL,
  `note` varchar(1000) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `created_at` datetime(6) NOT NULL,
  `updated_at` datetime(6) DEFAULT NULL,
  `deleted` tinyint(1) NOT NULL DEFAULT '0',
  PRIMARY KEY (`id`),
  UNIQUE KEY `maintenance_code` (`maintenance_code`),
  KEY `fk_maintenance_assigned_to` (`assigned_to`),
  KEY `idx_maintenance_vehicle_status` (`vehicle_id`,`status`),
  KEY `idx_maintenance_scheduled_date` (`scheduled_date`),
  CONSTRAINT `fk_maintenance_assigned_to` FOREIGN KEY (`assigned_to`) REFERENCES `users` (`id`),
  CONSTRAINT `fk_maintenance_vehicle` FOREIGN KEY (`vehicle_id`) REFERENCES `vehicles` (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=4 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `maintenance_orders`
--

LOCK TABLES `maintenance_orders` WRITE;
/*!40000 ALTER TABLE `maintenance_orders` DISABLE KEYS */;
INSERT INTO `maintenance_orders` VALUES (1,'MTN-DEMO-001',6,'PERIODIC','Bao tri demo 1','Kiem tra phanh, lop, den va thiet bi GPS','2026-07-28',NULL,1500000.00,'SCHEDULED','MEDIUM',1,NULL,'2026-07-27 00:05:48.139041','2026-07-27 00:05:48.139041',0),(2,'MTN-DEMO-002',7,'REPAIR','Bao tri demo 2','Kiem tra phanh, lop, den va thiet bi GPS','2026-07-29',NULL,2000000.00,'SCHEDULED','MEDIUM',1,NULL,'2026-07-27 00:05:48.141882','2026-07-27 00:05:48.141882',0),(3,'MTN-DEMO-003',8,'REPAIR','Bao tri demo 3','Kiem tra phanh, lop, den va thiet bi GPS','2026-07-30',NULL,2500000.00,'SCHEDULED','HIGH',1,NULL,'2026-07-27 00:05:48.143589','2026-07-27 00:05:48.143589',0);
/*!40000 ALTER TABLE `maintenance_orders` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `mobile_command_receipts`
--

DROP TABLE IF EXISTS `mobile_command_receipts`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `mobile_command_receipts` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `user_id` bigint NOT NULL,
  `client_event_id` varchar(100) COLLATE utf8mb4_unicode_ci NOT NULL,
  `operation` varchar(50) COLLATE utf8mb4_unicode_ci NOT NULL,
  `trip_id` bigint DEFAULT NULL,
  `response_json` longtext COLLATE utf8mb4_unicode_ci NOT NULL,
  `created_at` datetime(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  `updated_at` datetime(6) DEFAULT NULL,
  `deleted` tinyint(1) NOT NULL DEFAULT '0',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_mobile_receipt_user_event` (`user_id`,`client_event_id`),
  KEY `idx_mobile_receipt_trip_created` (`trip_id`,`created_at`),
  CONSTRAINT `fk_mobile_receipt_trip` FOREIGN KEY (`trip_id`) REFERENCES `trips` (`id`),
  CONSTRAINT `fk_mobile_receipt_user` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=3 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `mobile_command_receipts`
--

LOCK TABLES `mobile_command_receipts` WRITE;
/*!40000 ALTER TABLE `mobile_command_receipts` DISABLE KEYS */;
INSERT INTO `mobile_command_receipts` VALUES (1,6,'docker-workflow-start-d3acd1030e5545a0b4c9c8801bc22d70','START',11,'{\"action\":\"STARTED\",\"trip\":{\"id\":11,\"tripCode\":\"TRIP-20260727032315-7529\",\"vehicleId\":1,\"vehiclePlateNumber\":\"30H-100.01\",\"driverId\":1,\"driverName\":\"Nguyen Van An\",\"startLocation\":\"SafeFleet Docker Depot\",\"startLat\":21.0278,\"startLng\":105.8342,\"endLocation\":\"SafeFleet Docker Destination\",\"endLat\":21.045,\"endLng\":105.82,\"waypoints\":null,\"plannedRoute\":null,\"actualRoute\":null,\"plannedStartTime\":\"2026-07-27T03:33:14\",\"actualStartTime\":\"2026-07-27T03:23:15.491336943\",\"estimatedEndTime\":\"2026-07-27T05:23:14\",\"actualEndTime\":null,\"status\":\"IN_PROGRESS\",\"progress\":5,\"riskLevel\":\"LOW\"},\"drivingSession\":{\"id\":2,\"driverId\":1,\"vehicleId\":1,\"tripId\":11,\"status\":\"ACTIVE\",\"startedAt\":\"2026-07-27T03:23:15.527259824\",\"pausedAt\":null,\"resumedAt\":\"2026-07-27T03:23:15.527259824\",\"endedAt\":null,\"continuousMinutes\":0,\"totalMinutes\":0,\"overDrivingAlertCreated\":false},\"navigationSessionId\":\"eca22aee-09df-42d1-839c-4fcdb8199aae\"}','2026-07-27 03:23:15.552982','2026-07-27 03:23:15.552982',0),(2,6,'docker-workflow-complete-f5eaa8c352194076b24614557944629d','COMPLETE',11,'{\"action\":\"COMPLETED\",\"trip\":{\"id\":11,\"tripCode\":\"TRIP-20260727032315-7529\",\"vehicleId\":1,\"vehiclePlateNumber\":\"30H-100.01\",\"driverId\":1,\"driverName\":\"Nguyen Van An\",\"startLocation\":\"SafeFleet Docker Depot\",\"startLat\":21.0278,\"startLng\":105.8342,\"endLocation\":\"SafeFleet Docker Destination\",\"endLat\":21.045,\"endLng\":105.82,\"waypoints\":null,\"plannedRoute\":null,\"actualRoute\":null,\"plannedStartTime\":\"2026-07-27T03:33:14\",\"actualStartTime\":\"2026-07-27T03:23:15.491337\",\"estimatedEndTime\":\"2026-07-27T05:23:14\",\"actualEndTime\":\"2026-07-27T03:23:15.711103277\",\"status\":\"COMPLETED\",\"progress\":100,\"riskLevel\":\"LOW\"},\"drivingSession\":{\"id\":2,\"driverId\":1,\"vehicleId\":1,\"tripId\":11,\"status\":\"FINISHED\",\"startedAt\":\"2026-07-27T03:23:15.52726\",\"pausedAt\":null,\"resumedAt\":\"2026-07-27T03:23:15.722382056\",\"endedAt\":\"2026-07-27T03:23:15.722537729\",\"continuousMinutes\":0,\"totalMinutes\":0,\"overDrivingAlertCreated\":false},\"navigationSessionId\":\"eca22aee-09df-42d1-839c-4fcdb8199aae\"}','2026-07-27 03:23:15.741889','2026-07-27 03:23:15.741889',0);
/*!40000 ALTER TABLE `mobile_command_receipts` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `mobile_devices`
--

DROP TABLE IF EXISTS `mobile_devices`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `mobile_devices` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `device_uuid` varchar(100) COLLATE utf8mb4_unicode_ci NOT NULL,
  `user_id` bigint NOT NULL,
  `platform` varchar(20) COLLATE utf8mb4_unicode_ci NOT NULL,
  `app_version` varchar(40) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `os_version` varchar(80) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `device_model` varchar(120) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `last_seen_at` datetime(6) DEFAULT NULL,
  `created_at` datetime(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  `updated_at` datetime(6) DEFAULT NULL,
  `deleted` tinyint(1) NOT NULL DEFAULT '0',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_mobile_devices_uuid` (`device_uuid`),
  KEY `idx_mobile_devices_user` (`user_id`),
  KEY `idx_mobile_devices_last_seen` (`last_seen_at`),
  CONSTRAINT `fk_mobile_devices_user` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=2 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `mobile_devices`
--

LOCK TABLES `mobile_devices` WRITE;
/*!40000 ALTER TABLE `mobile_devices` DISABLE KEYS */;
INSERT INTO `mobile_devices` VALUES (1,'docker-e2e-1785092858727',6,'ANDROID','1.0.0','Android 15','Docker E2E','2026-07-27 02:07:38.878035','2026-07-27 02:07:38.878035','2026-07-27 02:07:38.878035',0);
/*!40000 ALTER TABLE `mobile_devices` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `navigation_events`
--

DROP TABLE IF EXISTS `navigation_events`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `navigation_events` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `navigation_session_id` bigint NOT NULL,
  `event_type` varchar(40) COLLATE utf8mb4_unicode_ci NOT NULL,
  `lat` double DEFAULT NULL,
  `lng` double DEFAULT NULL,
  `distance_to_hazard_meters` int DEFAULT NULL,
  `distance_to_route_meters` int DEFAULT NULL,
  `gps_accuracy_meters` decimal(8,2) DEFAULT NULL,
  `payload_json` json DEFAULT NULL,
  `occurred_at` datetime(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  `created_at` datetime(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  PRIMARY KEY (`id`),
  KEY `idx_navigation_events_session_created` (`navigation_session_id`,`created_at`),
  KEY `idx_navigation_events_type_created` (`event_type`,`created_at`),
  KEY `idx_navigation_events_session_occurred` (`navigation_session_id`,`occurred_at`),
  CONSTRAINT `fk_navigation_events_session` FOREIGN KEY (`navigation_session_id`) REFERENCES `navigation_sessions` (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=3 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `navigation_events`
--

LOCK TABLES `navigation_events` WRITE;
/*!40000 ALTER TABLE `navigation_events` DISABLE KEYS */;
INSERT INTO `navigation_events` VALUES (1,2,'OFF_ROUTE_CANDIDATE',21.039,105.75,NULL,90,8.00,'{\"metadata\": \"\", \"sourceEventType\": \"LOCATION_UPDATE\"}','2026-07-27 00:43:22.000000','2026-07-27 00:43:42.277135'),(2,2,'OFF_ROUTE_CONFIRMED',21.0392,105.751,NULL,105,7.00,'{\"metadata\": \"\", \"sourceEventType\": \"LOCATION_UPDATE\"}','2026-07-27 00:43:38.000000','2026-07-27 00:43:42.313364');
/*!40000 ALTER TABLE `navigation_events` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `navigation_route_candidates`
--

DROP TABLE IF EXISTS `navigation_route_candidates`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `navigation_route_candidates` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `navigation_session_id` bigint NOT NULL,
  `route_index` int NOT NULL,
  `label` varchar(120) COLLATE utf8mb4_unicode_ci NOT NULL,
  `distance_meters` int NOT NULL,
  `duration_seconds` int NOT NULL,
  `risk_score` decimal(7,3) NOT NULL DEFAULT '0.000',
  `total_score` decimal(10,3) NOT NULL DEFAULT '0.000',
  `flood_penalty` decimal(10,3) NOT NULL DEFAULT '0.000',
  `vehicle_restriction_penalty` decimal(10,3) NOT NULL DEFAULT '0.000',
  `driver_time_penalty` decimal(10,3) NOT NULL DEFAULT '0.000',
  `safe` tinyint(1) NOT NULL DEFAULT '1',
  `blocked` tinyint(1) NOT NULL DEFAULT '0',
  `flood_intersection_count` int NOT NULL DEFAULT '0',
  `is_recommended` tinyint(1) NOT NULL DEFAULT '0',
  `geometry_json` json NOT NULL,
  `steps_json` json DEFAULT NULL,
  `warnings_json` json DEFAULT NULL,
  `provider` varchar(40) COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'LOCAL_DEMO',
  `created_at` datetime(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_navigation_candidate_index` (`navigation_session_id`,`route_index`),
  KEY `idx_navigation_candidate_recommended` (`navigation_session_id`,`is_recommended`),
  CONSTRAINT `fk_navigation_candidates_session` FOREIGN KEY (`navigation_session_id`) REFERENCES `navigation_sessions` (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=2 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `navigation_route_candidates`
--

LOCK TABLES `navigation_route_candidates` WRITE;
/*!40000 ALTER TABLE `navigation_route_candidates` DISABLE KEYS */;
INSERT INTO `navigation_route_candidates` VALUES (1,2,0,'Đề xuất ít rủi ro nhất',11167,655,200.800,222.885,200.800,0.000,0.000,1,0,5,1,'[[105.746702, 21.038517], [105.746585, 21.038268], [105.746427, 21.037923], [105.746284, 21.037978], [105.745534, 21.038268], [105.744137, 21.038813], [105.743605, 21.039029], [105.743389, 21.039113], [105.743074, 21.039235], [105.742585, 21.039428], [105.742062, 21.039633], [105.741734, 21.039761], [105.741551, 21.039832], [105.741417, 21.039879], [105.741166, 21.039974], [105.741132, 21.039987], [105.739864, 21.040477], [105.738379, 21.041068], [105.738209, 21.041142], [105.737998, 21.041226], [105.737907, 21.041266], [105.737908, 21.041354], [105.73791, 21.041613], [105.737906, 21.041861], [105.737892, 21.042148], [105.737886, 21.042372], [105.737878, 21.042422], [105.737862, 21.04253], [105.737815, 21.042786], [105.737746, 21.043065], [105.73762, 21.043412], [105.737543, 21.043625], [105.737327, 21.044162], [105.737307, 21.044207], [105.737109, 21.044679], [105.736837, 21.04531], [105.73658, 21.045918], [105.735945, 21.047319], [105.735779, 21.047721], [105.735668, 21.047969], [105.735581, 21.048188], [105.735499, 21.048463], [105.73545, 21.048726], [105.73543, 21.048926], [105.735416, 21.049136], [105.735433, 21.049151], [105.735455, 21.04919], [105.735463, 21.049233], [105.735456, 21.049276], [105.735435, 21.049315], [105.735402, 21.049346], [105.735416, 21.04945], [105.735441, 21.049643], [105.735469, 21.049801], [105.73561, 21.05046], [105.735774, 21.051173], [105.735865, 21.051556], [105.73588, 21.051618], [105.735999, 21.051642], [105.736124, 21.051672], [105.736182, 21.051683], [105.736326, 21.051726], [105.736411, 21.051671], [105.736538, 21.051588], [105.736744, 21.051446], [105.736769, 21.051429], [105.737047, 21.051228], [105.737679, 21.050801], [105.737735, 21.050774], [105.737987, 21.050627], [105.738306, 21.050475], [105.738651, 21.050327], [105.740102, 21.049732], [105.740704, 21.049502], [105.742158, 21.048928], [105.743138, 21.048536], [105.743392, 21.048431], [105.743702, 21.048304], [105.743965, 21.0482], [105.744401, 21.04803], [105.74501, 21.047793], [105.745134, 21.047745], [105.745581, 21.04757], [105.746142, 21.04735], [105.746751, 21.047104], [105.747197, 21.046937], [105.747481, 21.046831], [105.74757, 21.046799], [105.747956, 21.046656], [105.748237, 21.046549], [105.74845, 21.046473], [105.748681, 21.046384], [105.749226, 21.046161], [105.749302, 21.04613], [105.749446, 21.046072], [105.751307, 21.045351], [105.751385, 21.045321], [105.75167, 21.045214], [105.752044, 21.045064], [105.752934, 21.044704], [105.753286, 21.044559], [105.754833, 21.043979], [105.755483, 21.043736], [105.75563, 21.043681], [105.755809, 21.043613], [105.756348, 21.043411], [105.756418, 21.043386], [105.756462, 21.04337], [105.756615, 21.043313], [105.756777, 21.043253], [105.757025, 21.043162], [105.758132, 21.04275], [105.758283, 21.042692], [105.758409, 21.042645], [105.758454, 21.042629], [105.759546, 21.042225], [105.760263, 21.041967], [105.760983, 21.041719], [105.761208, 21.04164], [105.761657, 21.041482], [105.761989, 21.041372], [105.762263, 21.041276], [105.763733, 21.040747], [105.764035, 21.040639], [105.764861, 21.040363], [105.765462, 21.040168], [105.766236, 21.039917], [105.767204, 21.039604], [105.767491, 21.039516], [105.767593, 21.039484], [105.76778, 21.039427], [105.767898, 21.039387], [105.767941, 21.039373], [105.767955, 21.039369], [105.769213, 21.039011], [105.769263, 21.038997], [105.769464, 21.038937], [105.769658, 21.038883], [105.770961, 21.038494], [105.771414, 21.03837], [105.771615, 21.038319], [105.771843, 21.038253], [105.771935, 21.038226], [105.772114, 21.038179], [105.772248, 21.038144], [105.772457, 21.038087], [105.772555, 21.038063], [105.773219, 21.0379], [105.773401, 21.037856], [105.773622, 21.037797], [105.7738, 21.037749], [105.773982, 21.037695], [105.774063, 21.037671], [105.774252, 21.037614], [105.77476, 21.03746], [105.77494, 21.037403], [105.77509, 21.037357], [105.775651, 21.037189], [105.775999, 21.037086], [105.776027, 21.037077], [105.776335, 21.036986], [105.776847, 21.036842], [105.777366, 21.036696], [105.777603, 21.036643], [105.777948, 21.036582], [105.778282, 21.036537], [105.778829, 21.036507], [105.779309, 21.036516], [105.779422, 21.036516], [105.779491, 21.036509], [105.779509, 21.036509], [105.779735, 21.036478], [105.779774, 21.036472], [105.780057, 21.036398], [105.780232, 21.036382], [105.780709, 21.036365], [105.780858, 21.036395], [105.781161, 21.036513], [105.78135, 21.036581], [105.781492, 21.036609], [105.781618, 21.036616], [105.781791, 21.036624], [105.781839, 21.036623], [105.781871, 21.036623], [105.783054, 21.036588], [105.783075, 21.036587], [105.783135, 21.036587], [105.783152, 21.036586], [105.783531, 21.036576], [105.784155, 21.036558], [105.784723, 21.036542], [105.784814, 21.03654], [105.785411, 21.036523], [105.785532, 21.036519], [105.785642, 21.036516], [105.785859, 21.036505], [105.785947, 21.036501], [105.786045, 21.036495], [105.786706, 21.03646], [105.787404, 21.03644], [105.787485, 21.036436], [105.787634, 21.036428], [105.787956, 21.036411], [105.788086, 21.036404], [105.788502, 21.036384], [105.788711, 21.036374], [105.788783, 21.036372], [105.788787, 21.036372], [105.788852, 21.036368], [105.788861, 21.036367], [105.789166, 21.036351], [105.789369, 21.036334], [105.789489, 21.036324], [105.78974, 21.036296], [105.789941, 21.036269], [105.790028, 21.036255], [105.790265, 21.036199], [105.790522, 21.036125], [105.790533, 21.036121], [105.791339, 21.035867], [105.79149, 21.03582], [105.791544, 21.035802], [105.791581, 21.035789], [105.791691, 21.035752], [105.792221, 21.035576], [105.792778, 21.035391], [105.793226, 21.035236], [105.793373, 21.035188], [105.793481, 21.035153], [105.793567, 21.035121], [105.793696, 21.035073], [105.793886, 21.035002], [105.794613, 21.034766], [105.795141, 21.034595], [105.795445, 21.034503], [105.79589, 21.034364], [105.796034, 21.03432], [105.796196, 21.034272], [105.796221, 21.034265], [105.796742, 21.03411], [105.796912, 21.034054], [105.797092, 21.033983], [105.797215, 21.03392], [105.797324, 21.033853], [105.797425, 21.03378], [105.797531, 21.033686], [105.797663, 21.033566], [105.79767, 21.033559], [105.797746, 21.033485], [105.797792, 21.03344], [105.798084, 21.03315], [105.798491, 21.032744], [105.798753, 21.032496], [105.798958, 21.032302], [105.799367, 21.031915], [105.799381, 21.0319], [105.799479, 21.031805], [105.79988, 21.031414], [105.800223, 21.031079], [105.800418, 21.030883], [105.800792, 21.030533], [105.800945, 21.030407], [105.801032, 21.030345], [105.801069, 21.030321], [105.801137, 21.030277], [105.801418, 21.03009], [105.801445, 21.030066], [105.801515, 21.030011], [105.80174, 21.029838], [105.801789, 21.029797], [105.801883, 21.029894], [105.801988, 21.030001], [105.802175, 21.030231], [105.802474, 21.030626], [105.802795, 21.030965], [105.80305, 21.031103], [105.80311, 21.031177], [105.803361, 21.031521], [105.803552, 21.031784], [105.804172, 21.032673], [105.804436, 21.033074], [105.804501, 21.033172], [105.804787, 21.033622], [105.804923, 21.033837], [105.805039, 21.034017], [105.805144, 21.034145], [105.805215, 21.034241], [105.805308, 21.034383], [105.805391, 21.034525], [105.805445, 21.03462], [105.805488, 21.034667], [105.805555, 21.034768], [105.805791, 21.035123], [105.806225, 21.035719], [105.806346, 21.035896], [105.806447, 21.036026], [105.806565, 21.036174], [105.806658, 21.036279], [105.806715, 21.036364], [105.806785, 21.036501], [105.80691, 21.036776], [105.806995, 21.037015], [105.807032, 21.037145], [105.807071, 21.037275], [105.807101, 21.037398], [105.807125, 21.037495], [105.807127, 21.037575], [105.807138, 21.03773], [105.807143, 21.037821], [105.807147, 21.037908], [105.807148, 21.038043], [105.807137, 21.03836], [105.807128, 21.038476], [105.807111, 21.038653], [105.807079, 21.038887], [105.807065, 21.039125], [105.807049, 21.039297], [105.807048, 21.039679], [105.806987, 21.040225], [105.806942, 21.040518], [105.807185, 21.040866], [105.80754, 21.041026], [105.80786, 21.041087], [105.807883, 21.041093], [105.808079, 21.041126], [105.808098, 21.041014]]','[{\"lat\": 21.038517, \"lng\": 105.746702, \"modifier\": \"right\", \"roadName\": \"\", \"instruction\": \"Rẽ phải\", \"maneuverType\": \"depart\", \"distanceMeters\": 71.7, \"durationSeconds\": 19.3}, {\"lat\": 21.037923, \"lng\": 105.746427, \"modifier\": \"right\", \"roadName\": \"Phố Phan Tây Nhạc\", \"instruction\": \"Rẽ phải vào Phố Phan Tây Nhạc\", \"maneuverType\": \"end of road\", \"distanceMeters\": 960.0, \"durationSeconds\": 65.3}, {\"lat\": 21.041266, \"lng\": 105.737907, \"modifier\": \"right\", \"roadName\": \"Đường Xuân Phương\", \"instruction\": \"Rẽ phải vào Đường Xuân Phương\", \"maneuverType\": \"turn\", \"distanceMeters\": 917.7, \"durationSeconds\": 50.9}, {\"lat\": 21.049136, \"lng\": 105.735416, \"modifier\": \"right\", \"roadName\": \"Đường Xuân Phương\", \"instruction\": \"Rẽ phải vào Đường Xuân Phương\", \"maneuverType\": \"roundabout\", \"distanceMeters\": 26.7, \"durationSeconds\": 1.8}, {\"lat\": 21.049346, \"lng\": 105.735402, \"modifier\": \"right\", \"roadName\": \"Đường Xuân Phương\", \"instruction\": \"Rẽ phải vào Đường Xuân Phương\", \"maneuverType\": \"exit roundabout\", \"distanceMeters\": 256.5, \"durationSeconds\": 14.6}, {\"lat\": 21.051618, \"lng\": 105.73588, \"modifier\": \"right\", \"roadName\": \"\", \"instruction\": \"Rẽ phải\", \"maneuverType\": \"on ramp\", \"distanceMeters\": 47.9, \"durationSeconds\": 4.4}, {\"lat\": 21.051726, \"lng\": 105.736326, \"modifier\": \"slight left\", \"roadName\": \"Đường Cầu Diễn\", \"instruction\": \"Rẽ trái vào Đường Cầu Diễn\", \"maneuverType\": \"merge\", \"distanceMeters\": 2872.5, \"durationSeconds\": 121.9}, {\"lat\": 21.041482, \"lng\": 105.761657, \"modifier\": \"straight\", \"roadName\": \"Đường Hồ Tùng Mậu\", \"instruction\": \"Tiếp tục vào Đường Hồ Tùng Mậu\", \"maneuverType\": \"new name\", \"distanceMeters\": 2084.3, \"durationSeconds\": 125.0}, {\"lat\": 21.036395, \"lng\": 105.780858, \"modifier\": \"slight left\", \"roadName\": \"Đường Xuân Thủy\", \"instruction\": \"Rẽ trái vào Đường Xuân Thủy\", \"maneuverType\": \"new name\", \"distanceMeters\": 902.4, \"durationSeconds\": 52.2}, {\"lat\": 21.036324, \"lng\": 105.789489, \"modifier\": \"straight\", \"roadName\": \"Đường Cầu Giấy\", \"instruction\": \"Tiếp tục vào Đường Cầu Giấy\", \"maneuverType\": \"new name\", \"distanceMeters\": 1508.2, \"durationSeconds\": 96.2}, {\"lat\": 21.029797, \"lng\": 105.801789, \"modifier\": \"left\", \"roadName\": \"Đường Bưởi\", \"instruction\": \"Rẽ trái vào Đường Bưởi\", \"maneuverType\": \"turn\", \"distanceMeters\": 1226.4, \"durationSeconds\": 70.0}, {\"lat\": 21.039297, \"lng\": 105.807049, \"modifier\": \"slight right\", \"roadName\": \"Đường Bưởi\", \"instruction\": \"Rẽ phải vào Đường Bưởi\", \"maneuverType\": \"fork\", \"distanceMeters\": 135.9, \"durationSeconds\": 7.6}, {\"lat\": 21.040518, \"lng\": 105.806942, \"modifier\": \"right\", \"roadName\": \"Ngõ 376 Đường Bưởi\", \"instruction\": \"Rẽ phải vào Ngõ 376 Đường Bưởi\", \"maneuverType\": \"turn\", \"distanceMeters\": 144.1, \"durationSeconds\": 23.0}, {\"lat\": 21.041126, \"lng\": 105.808079, \"modifier\": \"right\", \"roadName\": \"\", \"instruction\": \"Rẽ phải\", \"maneuverType\": \"turn\", \"distanceMeters\": 12.6, \"durationSeconds\": 2.9}, {\"lat\": 21.041014, \"lng\": 105.808098, \"modifier\": \"right\", \"roadName\": \"\", \"instruction\": \"Rẽ phải\", \"maneuverType\": \"arrive\", \"distanceMeters\": 0.0, \"durationSeconds\": 0.0}]','[\"MEDIUM cách tuyến 52 m tại [DEMO] Cau Giay\", \"MEDIUM cách tuyến 143 m tại [DEMO] Kieu Mai\", \"HIGH cách tuyến 110 m tại [DEMO] Phu Dien\", \"MEDIUM cách tuyến 75 m tại [DEMO] Ho Tung Mau\", \"HIGH cách tuyến 20 m tại [E2E] Diem ngap test Ho Tung Mau\"]','OSRM','2026-07-27 00:43:42.125198');
/*!40000 ALTER TABLE `navigation_route_candidates` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `navigation_sessions`
--

DROP TABLE IF EXISTS `navigation_sessions`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `navigation_sessions` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `session_uuid` varchar(100) COLLATE utf8mb4_unicode_ci NOT NULL,
  `driver_id` bigint NOT NULL,
  `vehicle_id` bigint DEFAULT NULL,
  `trip_id` bigint DEFAULT NULL,
  `origin_lat` double NOT NULL,
  `origin_lng` double NOT NULL,
  `destination_lat` double NOT NULL,
  `destination_lng` double NOT NULL,
  `destination_name` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `selected_candidate_id` bigint DEFAULT NULL,
  `status` varchar(30) COLLATE utf8mb4_unicode_ci NOT NULL,
  `started_at` datetime(6) DEFAULT NULL,
  `ended_at` datetime(6) DEFAULT NULL,
  `created_at` datetime(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  `updated_at` datetime(6) DEFAULT NULL,
  `deleted` tinyint(1) NOT NULL DEFAULT '0',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_navigation_sessions_uuid` (`session_uuid`),
  KEY `fk_navigation_sessions_vehicle` (`vehicle_id`),
  KEY `idx_navigation_sessions_driver_status` (`driver_id`,`status`),
  KEY `idx_navigation_sessions_trip` (`trip_id`),
  KEY `fk_navigation_sessions_selected_candidate` (`selected_candidate_id`),
  CONSTRAINT `fk_navigation_sessions_driver` FOREIGN KEY (`driver_id`) REFERENCES `drivers` (`id`),
  CONSTRAINT `fk_navigation_sessions_selected_candidate` FOREIGN KEY (`selected_candidate_id`) REFERENCES `navigation_route_candidates` (`id`),
  CONSTRAINT `fk_navigation_sessions_trip` FOREIGN KEY (`trip_id`) REFERENCES `trips` (`id`),
  CONSTRAINT `fk_navigation_sessions_vehicle` FOREIGN KEY (`vehicle_id`) REFERENCES `vehicles` (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=4 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `navigation_sessions`
--

LOCK TABLES `navigation_sessions` WRITE;
/*!40000 ALTER TABLE `navigation_sessions` DISABLE KEYS */;
INSERT INTO `navigation_sessions` VALUES (1,'f0af6e39-e76c-4229-8a90-38110aace50d',8,8,8,21.0386,105.7465,21.041,105.808,'Ho Tung Mau',NULL,'COMPLETED','2026-07-27 00:26:18.258195','2026-07-27 00:26:18.418864','2026-07-27 00:26:18.258195','2026-07-27 00:26:18.418864',0),(2,'40473ec4-b622-4b26-adec-a624a7d8306d',8,8,NULL,21.0386,105.7465,21.041,105.808,'Ho Tung Mau',1,'ACTIVE','2026-07-27 00:43:41.203693',NULL,'2026-07-27 00:43:41.203693','2026-07-27 00:43:42.126247',0),(3,'eca22aee-09df-42d1-839c-4fcdb8199aae',1,1,11,21.0278,105.8342,21.045,105.82,'SafeFleet Docker Destination',NULL,'COMPLETED','2026-07-27 03:23:15.542054','2026-07-27 03:23:15.739656','2026-07-27 03:23:15.542054','2026-07-27 03:23:15.739656',0);
/*!40000 ALTER TABLE `navigation_sessions` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `notification_reads`
--

DROP TABLE IF EXISTS `notification_reads`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `notification_reads` (
  `notification_id` bigint NOT NULL,
  `user_id` bigint NOT NULL,
  `read_at` datetime(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  PRIMARY KEY (`notification_id`,`user_id`),
  KEY `idx_notification_reads_user` (`user_id`,`read_at`),
  CONSTRAINT `fk_notification_reads_notification` FOREIGN KEY (`notification_id`) REFERENCES `notifications` (`id`),
  CONSTRAINT `fk_notification_reads_user` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `notification_reads`
--

LOCK TABLES `notification_reads` WRITE;
/*!40000 ALTER TABLE `notification_reads` DISABLE KEYS */;
INSERT INTO `notification_reads` VALUES (3,6,'2026-07-27 00:09:07.333736');
/*!40000 ALTER TABLE `notification_reads` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `notifications`
--

DROP TABLE IF EXISTS `notifications`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `notifications` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `recipient_id` bigint DEFAULT NULL,
  `type` varchar(40) COLLATE utf8mb4_unicode_ci NOT NULL,
  `title` varchar(150) COLLATE utf8mb4_unicode_ci NOT NULL,
  `content` varchar(500) COLLATE utf8mb4_unicode_ci NOT NULL,
  `reference_type` varchar(50) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `reference_id` bigint DEFAULT NULL,
  `read_at` datetime(6) DEFAULT NULL,
  `created_at` datetime(6) NOT NULL,
  PRIMARY KEY (`id`),
  KEY `idx_notifications_recipient_created` (`recipient_id`,`created_at`),
  KEY `idx_notifications_read_at` (`read_at`),
  CONSTRAINT `fk_notifications_recipient` FOREIGN KEY (`recipient_id`) REFERENCES `users` (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=9 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `notifications`
--

LOCK TABLES `notifications` WRITE;
/*!40000 ALTER TABLE `notifications` DISABLE KEYS */;
INSERT INTO `notifications` VALUES (1,NULL,'FLOOD','Diem ngap moi','[E2E] Diem ngap test Ho Tung Mau','FLOOD_REPORT',9,NULL,'2026-07-27 00:07:35.043904'),(2,NULL,'AI_ALERT','Canh bao AI moi','PHONE_USAGE - HIGH','SAFETY_EVENT',16,NULL,'2026-07-27 00:07:35.087284'),(3,NULL,'SOS','SOS moi','[E2E] SOS integration verification','INCIDENT',6,NULL,'2026-07-27 00:07:35.127564'),(4,NULL,'AI_ALERT','Canh bao AI moi','PHONE_USAGE - HIGH','SAFETY_EVENT',17,NULL,'2026-07-27 02:07:39.065334'),(5,NULL,'SOS','SOS moi','Docker real API SOS','INCIDENT',7,NULL,'2026-07-27 02:07:39.706269'),(6,NULL,'AI_ALERT','Canh bao AI moi','DROWSINESS - HIGH','SAFETY_EVENT',18,NULL,'2026-07-27 03:12:40.389031'),(7,NULL,'FLOOD','Diem ngap moi','Docker flood test Hanoi','FLOOD_REPORT',10,NULL,'2026-07-27 03:15:54.377017'),(8,NULL,'FLOOD','Diem ngap moi','Docker flood idempotency Hanoi','FLOOD_REPORT',11,NULL,'2026-07-27 03:21:46.216741');
/*!40000 ALTER TABLE `notifications` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `pending_push_notifications`
--

DROP TABLE IF EXISTS `pending_push_notifications`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `pending_push_notifications` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `notification_id` bigint DEFAULT NULL,
  `user_id` bigint NOT NULL,
  `push_token_id` bigint DEFAULT NULL,
  `title` varchar(150) COLLATE utf8mb4_unicode_ci NOT NULL,
  `body` varchar(500) COLLATE utf8mb4_unicode_ci NOT NULL,
  `data_json` json DEFAULT NULL,
  `status` varchar(30) COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'PENDING',
  `attempt_count` int NOT NULL DEFAULT '0',
  `next_attempt_at` datetime(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  `sent_at` datetime(6) DEFAULT NULL,
  `last_error` varchar(1000) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `created_at` datetime(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  PRIMARY KEY (`id`),
  KEY `fk_pending_push_notification` (`notification_id`),
  KEY `fk_pending_push_token` (`push_token_id`),
  KEY `idx_pending_push_dispatch` (`status`,`next_attempt_at`),
  KEY `idx_pending_push_user_created` (`user_id`,`created_at`),
  CONSTRAINT `fk_pending_push_notification` FOREIGN KEY (`notification_id`) REFERENCES `notifications` (`id`),
  CONSTRAINT `fk_pending_push_token` FOREIGN KEY (`push_token_id`) REFERENCES `push_tokens` (`id`),
  CONSTRAINT `fk_pending_push_user` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=6 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `pending_push_notifications`
--

LOCK TABLES `pending_push_notifications` WRITE;
/*!40000 ALTER TABLE `pending_push_notifications` DISABLE KEYS */;
INSERT INTO `pending_push_notifications` VALUES (1,4,6,1,'Canh bao AI moi','PHONE_USAGE - HIGH','{\"referenceId\": 17, \"referenceType\": \"SAFETY_EVENT\"}','POLLING_FALLBACK',0,'2026-07-27 02:07:39.088142',NULL,'FCM disabled; mobile REST polling remains active','2026-07-27 02:07:39.088142'),(2,5,6,1,'SOS moi','Docker real API SOS','{\"referenceId\": 7, \"referenceType\": \"INCIDENT\"}','POLLING_FALLBACK',0,'2026-07-27 02:07:39.710643',NULL,'FCM disabled; mobile REST polling remains active','2026-07-27 02:07:39.710643'),(3,6,6,1,'Canh bao AI moi','DROWSINESS - HIGH','{\"referenceId\": 18, \"referenceType\": \"SAFETY_EVENT\"}','POLLING_FALLBACK',0,'2026-07-27 03:12:40.562539',NULL,'FCM disabled; mobile REST polling remains active','2026-07-27 03:12:40.562539'),(4,7,6,1,'Diem ngap moi','Docker flood test Hanoi','{\"referenceId\": 10, \"referenceType\": \"FLOOD_REPORT\"}','POLLING_FALLBACK',0,'2026-07-27 03:15:54.409189',NULL,'FCM disabled; mobile REST polling remains active','2026-07-27 03:15:54.409189'),(5,8,6,1,'Diem ngap moi','Docker flood idempotency Hanoi','{\"referenceId\": 11, \"referenceType\": \"FLOOD_REPORT\"}','POLLING_FALLBACK',0,'2026-07-27 03:21:46.231303',NULL,'FCM disabled; mobile REST polling remains active','2026-07-27 03:21:46.231303');
/*!40000 ALTER TABLE `pending_push_notifications` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `permissions`
--

DROP TABLE IF EXISTS `permissions`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `permissions` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `code` varchar(100) COLLATE utf8mb4_unicode_ci NOT NULL,
  `description` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `created_at` datetime(6) NOT NULL,
  `updated_at` datetime(6) DEFAULT NULL,
  `deleted` tinyint(1) NOT NULL DEFAULT '0',
  PRIMARY KEY (`id`),
  UNIQUE KEY `code` (`code`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `permissions`
--

LOCK TABLES `permissions` WRITE;
/*!40000 ALTER TABLE `permissions` DISABLE KEYS */;
/*!40000 ALTER TABLE `permissions` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `pre_trip_checklists`
--

DROP TABLE IF EXISTS `pre_trip_checklists`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `pre_trip_checklists` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `trip_id` bigint NOT NULL,
  `driver_id` bigint NOT NULL,
  `vehicle_id` bigint DEFAULT NULL,
  `exterior_checked` tinyint(1) NOT NULL DEFAULT '0',
  `tires_checked` tinyint(1) NOT NULL DEFAULT '0',
  `brake_checked` tinyint(1) NOT NULL DEFAULT '0',
  `lights_checked` tinyint(1) NOT NULL DEFAULT '0',
  `camera_checked` tinyint(1) NOT NULL DEFAULT '0',
  `gps_checked` tinyint(1) NOT NULL DEFAULT '0',
  `documents_checked` tinyint(1) NOT NULL DEFAULT '0',
  `checklist_json` json DEFAULT NULL,
  `note` varchar(500) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `created_at` datetime(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  `updated_at` datetime(6) DEFAULT NULL,
  `deleted` tinyint(1) NOT NULL DEFAULT '0',
  PRIMARY KEY (`id`),
  KEY `fk_pre_trip_vehicle` (`vehicle_id`),
  KEY `idx_pre_trip_trip_driver` (`trip_id`,`driver_id`),
  KEY `idx_pre_trip_driver_created` (`driver_id`,`created_at`),
  CONSTRAINT `fk_pre_trip_driver` FOREIGN KEY (`driver_id`) REFERENCES `drivers` (`id`),
  CONSTRAINT `fk_pre_trip_trip` FOREIGN KEY (`trip_id`) REFERENCES `trips` (`id`),
  CONSTRAINT `fk_pre_trip_vehicle` FOREIGN KEY (`vehicle_id`) REFERENCES `vehicles` (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=3 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `pre_trip_checklists`
--

LOCK TABLES `pre_trip_checklists` WRITE;
/*!40000 ALTER TABLE `pre_trip_checklists` DISABLE KEYS */;
INSERT INTO `pre_trip_checklists` VALUES (1,8,8,8,1,1,1,1,1,1,1,'{\"gpsChecked\": true, \"brakeChecked\": true, \"tiresChecked\": true, \"cameraChecked\": true, \"lightsChecked\": true, \"exteriorChecked\": true, \"documentsChecked\": true}','[E2E Docker] all checks passed','2026-07-27 00:25:49.661865','2026-07-27 00:25:49.661865',0),(2,11,1,1,1,1,1,1,1,1,1,'{\"gpsChecked\": true, \"brakeChecked\": true, \"tiresChecked\": true, \"cameraChecked\": true, \"lightsChecked\": true, \"exteriorChecked\": true, \"documentsChecked\": true}','Docker workflow verification','2026-07-27 03:23:15.362079','2026-07-27 03:23:15.362079',0);
/*!40000 ALTER TABLE `pre_trip_checklists` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `push_tokens`
--

DROP TABLE IF EXISTS `push_tokens`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `push_tokens` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `user_id` bigint NOT NULL,
  `device_id` bigint DEFAULT NULL,
  `provider` varchar(30) COLLATE utf8mb4_unicode_ci NOT NULL,
  `token` varchar(512) COLLATE utf8mb4_unicode_ci NOT NULL,
  `enabled` tinyint(1) NOT NULL DEFAULT '1',
  `last_used_at` datetime(6) DEFAULT NULL,
  `created_at` datetime(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  `updated_at` datetime(6) DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_push_tokens_provider_token` (`provider`,`token`),
  KEY `fk_push_tokens_device` (`device_id`),
  KEY `idx_push_tokens_user_enabled` (`user_id`,`enabled`),
  CONSTRAINT `fk_push_tokens_device` FOREIGN KEY (`device_id`) REFERENCES `mobile_devices` (`id`),
  CONSTRAINT `fk_push_tokens_user` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=2 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `push_tokens`
--

LOCK TABLES `push_tokens` WRITE;
/*!40000 ALTER TABLE `push_tokens` DISABLE KEYS */;
INSERT INTO `push_tokens` VALUES (1,6,1,'FCM','e2e-fcm-1785092858727',1,'2026-07-27 02:07:38.889752','2026-07-27 02:07:38.889752','2026-07-27 02:07:38.889752');
/*!40000 ALTER TABLE `push_tokens` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `refresh_tokens`
--

DROP TABLE IF EXISTS `refresh_tokens`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `refresh_tokens` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `user_id` bigint NOT NULL,
  `token_hash` char(64) COLLATE utf8mb4_unicode_ci NOT NULL,
  `expires_at` datetime(6) NOT NULL,
  `revoked_at` datetime(6) DEFAULT NULL,
  `created_at` datetime(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  `last_used_at` datetime(6) DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_refresh_tokens_hash` (`token_hash`),
  KEY `idx_refresh_tokens_user_active` (`user_id`,`revoked_at`,`expires_at`),
  KEY `idx_refresh_tokens_expires` (`expires_at`),
  CONSTRAINT `fk_refresh_tokens_user` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=36 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `refresh_tokens`
--

LOCK TABLES `refresh_tokens` WRITE;
/*!40000 ALTER TABLE `refresh_tokens` DISABLE KEYS */;
INSERT INTO `refresh_tokens` VALUES (1,1,'f6cd52af418184d6891c000ad991b79c7a0d9c90961b857733994204edefb9e7','2026-08-26 00:06:36.581017',NULL,'2026-07-27 00:06:36.583762',NULL),(2,6,'76776f11600fc4325f4aee47f3a97febfc813514f1f5cb93b8ed25a08e80575c','2026-08-26 00:06:36.798156','2026-07-27 00:06:36.979948','2026-07-27 00:06:36.798594','2026-07-27 00:06:36.979948'),(3,6,'71350e357b979532a5faf16df45698c946be53842b93eb7c7984ebca67c15cad','2026-08-26 00:06:36.982916','2026-07-27 00:06:37.059356','2026-07-27 00:06:36.983105','2026-07-27 00:06:37.059356'),(4,6,'acbc3ab09dfadf87f858a973e913d3901011d72cc3b8fb863a2f99da264a3b34','2026-08-26 00:06:57.371669',NULL,'2026-07-27 00:06:57.372013',NULL),(5,13,'9d4703ef5a03db7709eddeebe7f4336519f3720177fc981cfbe5aea28e032c8d','2026-08-26 00:07:34.837444',NULL,'2026-07-27 00:07:34.837831',NULL),(6,1,'bf8b48cfcf370cfa7d90f55172bfd670217653379d4631595a40c524c18dfac6','2026-08-26 00:08:52.769500',NULL,'2026-07-27 00:08:52.769914',NULL),(7,6,'54822aacc1104a840f8bd7d1e2cfe16a5cd4143ae81ae14ab22d097d8f9bcf65','2026-08-26 00:09:07.063716',NULL,'2026-07-27 00:09:07.064202',NULL),(8,7,'973af548713278f1b3e4d8000e6947b5dede74326d2ca84bf3308942e7ef0a7d','2026-08-26 00:09:07.207718',NULL,'2026-07-27 00:09:07.208144',NULL),(9,13,'30a65f698b6a700872d9ef43d7a82f626ac222f5880c5e4fabf399c8ba0fd9aa','2026-08-26 00:25:17.129091',NULL,'2026-07-27 00:25:17.132731',NULL),(10,13,'c33c54a7ec5e672a1154951b0bbebb119d5b0937f966e1403c34152dbbacab11','2026-08-26 00:25:25.887157',NULL,'2026-07-27 00:25:25.887767',NULL),(11,13,'16a4383b34eedf649eccd2cda631276bd1eb09d8dbe0ba1b90a14012a8075edf','2026-08-26 00:25:49.460999',NULL,'2026-07-27 00:25:49.461585',NULL),(12,13,'fc855231298c22824df21944798a017ba1baed2c2d53bc53f0d2e83b32336d95','2026-08-26 00:26:17.872421',NULL,'2026-07-27 00:26:17.872940',NULL),(13,13,'9f63021d755875e54c7783295cfb50edc52c02d60eaadddac9118ee561671bd2','2026-08-26 00:43:39.784448',NULL,'2026-07-27 00:43:39.788079',NULL),(14,6,'fcc43313c5013eaf2454707cbd3641db235908d2b6d21697dd3be693c5813671','2026-08-26 02:07:38.301671',NULL,'2026-07-27 02:07:38.307779',NULL),(15,7,'2b1f7ea851937b1d8fe65280d1197ab47c63e5d509e42ae8eb3f5a2a5137711b','2026-08-26 02:07:38.597808',NULL,'2026-07-27 02:07:38.598519',NULL),(16,1,'08f3fe0bb4ff5762ff24cb20e6989ea0eb403b2cda40ad901eb811855c6e42ef','2026-08-26 02:07:38.696425',NULL,'2026-07-27 02:07:38.697439',NULL),(17,6,'eba67263ca4327c542504abf07307bc7d3a44c92d45f6d2733a03f844985216b','2026-08-26 02:09:25.095843',NULL,'2026-07-27 02:09:25.096291',NULL),(18,6,'9471fb3e3ea4be06de9fc84f9da2bf953ae2b122fb4b2e0c32358f95b4c466d6','2026-08-26 02:11:37.926339',NULL,'2026-07-27 02:11:37.930541',NULL),(19,7,'55201b72d4edb9e1593dd644ec901d8c95114d9fbcc8119ada002706a1224405','2026-08-26 02:11:38.200034',NULL,'2026-07-27 02:11:38.200611',NULL),(20,1,'79e5f18f4536b9dadac91605bd17f855a05d985d1af15615a9dc36accfbd487a','2026-08-26 02:13:17.110764',NULL,'2026-07-27 02:13:17.114836',NULL),(21,1,'6e67cc3d321f5e5a59eeb89b8b6e20b5e89fb9aa101a3ed89afe52ea16cce9fc','2026-08-26 02:34:39.150298',NULL,'2026-07-27 02:34:39.166690',NULL),(22,6,'d95f7b7f0455c109162254e882d1a4a295d1d9b2abea11c72ae71932a2a06de3','2026-08-26 03:11:41.910795',NULL,'2026-07-27 03:11:41.921228',NULL),(23,6,'ed6e7814ff5d9c59cc495fb36ac62584c67fe5f8957e9be93e062e32ba6d30cc','2026-08-26 03:11:52.283089',NULL,'2026-07-27 03:11:52.284315',NULL),(24,6,'77b5993b1f6473a6239c447fd4e3424c27156a58e66e2bc08550f65c5b6c4538','2026-08-26 03:12:34.038658',NULL,'2026-07-27 03:12:34.108985',NULL),(25,6,'e915e7089bfffac26c019d05805c6aac1e94c778c71c6f0eb529adc4163eee7e','2026-08-26 03:14:39.018871',NULL,'2026-07-27 03:14:39.028818',NULL),(26,6,'aa677d156f2dbe98e1070f7766925e3bd59e24d1d0e9caa4d66a41477ea26cd2','2026-08-26 03:15:05.408327',NULL,'2026-07-27 03:15:05.414101',NULL),(27,6,'1a7762a4f0da00a197c2e5d6f1232ae6dabe50d2943ad4ceb20d47961c81d70f','2026-08-26 03:15:28.617698',NULL,'2026-07-27 03:15:28.621526',NULL),(28,6,'7eeea1f1eb6240c36b1a45f360557e487a0ceb457096a50d6f75362bf5f52dd2','2026-08-26 03:15:51.877361',NULL,'2026-07-27 03:15:51.878301',NULL),(29,6,'7f7b2af6ecda330def492cc0c44c035d342b43cfbca3f3895da4f87740042795','2026-08-26 03:21:45.504240',NULL,'2026-07-27 03:21:45.509170',NULL),(30,6,'3f527ade90af160264e72eaabc32b9869e6b0068e590110a7e06d59a3010ad30','2026-08-26 03:22:23.998240',NULL,'2026-07-27 03:22:23.999764',NULL),(31,1,'115f53f8f1c97d1abe07a120c18d8e8168109414940073e6611c5df68d410472','2026-08-26 03:23:14.700544',NULL,'2026-07-27 03:23:14.701267',NULL),(32,6,'550c6db2979876ae585b4b8477f2114e49dd9b4bd6ff429c30734f99914b28e3','2026-08-26 03:23:14.883685',NULL,'2026-07-27 03:23:14.884396',NULL),(33,1,'09002ba68e551ed1e43217a912e9c5ffd42d7c91c22235f8f9c1a3a6c869a41a','2026-08-26 03:48:49.556842',NULL,'2026-07-27 03:48:49.572350',NULL),(34,1,'5fffb5111f3b477ce31d5d72ae285d4f0fa852150f0c047a23ff35c13edb03e8','2026-08-26 09:55:13.189536',NULL,'2026-07-27 09:55:13.194799',NULL),(35,1,'241bcfb228f1b2cf96aa289efc260eda74f04a06eab6461c09d7425dcf14c864','2026-08-26 09:55:23.811092',NULL,'2026-07-27 09:55:23.811902',NULL);
/*!40000 ALTER TABLE `refresh_tokens` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `role_permissions`
--

DROP TABLE IF EXISTS `role_permissions`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `role_permissions` (
  `role_id` bigint NOT NULL,
  `permission_id` bigint NOT NULL,
  PRIMARY KEY (`role_id`,`permission_id`),
  KEY `fk_role_permissions_permission` (`permission_id`),
  CONSTRAINT `fk_role_permissions_permission` FOREIGN KEY (`permission_id`) REFERENCES `permissions` (`id`),
  CONSTRAINT `fk_role_permissions_role` FOREIGN KEY (`role_id`) REFERENCES `roles` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `role_permissions`
--

LOCK TABLES `role_permissions` WRITE;
/*!40000 ALTER TABLE `role_permissions` DISABLE KEYS */;
/*!40000 ALTER TABLE `role_permissions` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `roles`
--

DROP TABLE IF EXISTS `roles`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `roles` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `name` varchar(50) COLLATE utf8mb4_unicode_ci NOT NULL,
  `description` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `created_at` datetime(6) NOT NULL,
  `updated_at` datetime(6) DEFAULT NULL,
  `deleted` tinyint(1) NOT NULL DEFAULT '0',
  PRIMARY KEY (`id`),
  UNIQUE KEY `name` (`name`)
) ENGINE=InnoDB AUTO_INCREMENT=7 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `roles`
--

LOCK TABLES `roles` WRITE;
/*!40000 ALTER TABLE `roles` DISABLE KEYS */;
INSERT INTO `roles` VALUES (1,'ADMIN','System administrator','2026-07-26 23:59:54.397731','2026-07-26 23:59:54.397731',0),(2,'FLEET_MANAGER','Fleet manager','2026-07-26 23:59:54.397731','2026-07-26 23:59:54.397731',0),(3,'DISPATCHER','Trip dispatcher','2026-07-26 23:59:54.397731','2026-07-26 23:59:54.397731',0),(4,'SAFETY_OFFICER','Safety monitoring officer','2026-07-26 23:59:54.397731','2026-07-26 23:59:54.397731',0),(5,'RESCUE_TEAM','Rescue team member','2026-07-26 23:59:54.397731','2026-07-26 23:59:54.397731',0),(6,'DRIVER','Driver mobile app user','2026-07-26 23:59:54.397731','2026-07-26 23:59:54.397731',0);
/*!40000 ALTER TABLE `roles` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `safety_event_evidence`
--

DROP TABLE IF EXISTS `safety_event_evidence`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `safety_event_evidence` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `safety_event_id` bigint DEFAULT NULL,
  `incident_id` bigint DEFAULT NULL,
  `uploaded_by` bigint NOT NULL,
  `object_key` varchar(500) COLLATE utf8mb4_unicode_ci NOT NULL,
  `original_filename` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `content_type` varchar(120) COLLATE utf8mb4_unicode_ci NOT NULL,
  `size_bytes` bigint NOT NULL,
  `sha256` char(64) COLLATE utf8mb4_unicode_ci NOT NULL,
  `captured_at` datetime(6) DEFAULT NULL,
  `created_at` datetime(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  `deleted` tinyint(1) NOT NULL DEFAULT '0',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_evidence_object_key` (`object_key`),
  KEY `fk_evidence_uploaded_by` (`uploaded_by`),
  KEY `idx_evidence_safety_event` (`safety_event_id`),
  KEY `idx_evidence_incident` (`incident_id`),
  KEY `idx_evidence_sha256` (`sha256`),
  CONSTRAINT `fk_evidence_incident` FOREIGN KEY (`incident_id`) REFERENCES `incidents` (`id`),
  CONSTRAINT `fk_evidence_safety_event` FOREIGN KEY (`safety_event_id`) REFERENCES `safety_events` (`id`),
  CONSTRAINT `fk_evidence_uploaded_by` FOREIGN KEY (`uploaded_by`) REFERENCES `users` (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=3 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `safety_event_evidence`
--

LOCK TABLES `safety_event_evidence` WRITE;
/*!40000 ALTER TABLE `safety_event_evidence` DISABLE KEYS */;
INSERT INTO `safety_event_evidence` VALUES (1,17,NULL,6,'2026/07/27/ba1610bb-1a52-4845-89ed-9a3375492300.png','safefleet-evidence-1785093098232.png','image/png',68,'431ced6916a2a21a156e38701afe55bbd7f88969fbbfc56d7fe099d47f265460','2026-07-27 02:00:00.000000','2026-07-27 02:11:38.469365',0),(2,18,NULL,6,'2026/07/27/bd21d979-5125-40b2-aeba-30932fa5f7ec.png','ic_launcher.png','image/png',1443,'3c34e1f298d0c9ea3455d46db6b7759c8211a49e9ec6e44b635fc5c87dfb4180','2026-07-27 03:15:00.000000','2026-07-27 03:12:41.995971',0);
/*!40000 ALTER TABLE `safety_event_evidence` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `safety_events`
--

DROP TABLE IF EXISTS `safety_events`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `safety_events` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `event_type` varchar(40) COLLATE utf8mb4_unicode_ci NOT NULL,
  `severity` varchar(30) COLLATE utf8mb4_unicode_ci NOT NULL,
  `vehicle_id` bigint DEFAULT NULL,
  `driver_id` bigint DEFAULT NULL,
  `trip_id` bigint DEFAULT NULL,
  `lat` double DEFAULT NULL,
  `lng` double DEFAULT NULL,
  `speed` double DEFAULT NULL,
  `confidence` double DEFAULT NULL,
  `evidence_url` varchar(500) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `status` varchar(30) COLLATE utf8mb4_unicode_ci NOT NULL,
  `handled_by` bigint DEFAULT NULL,
  `handled_at` datetime(6) DEFAULT NULL,
  `note` varchar(500) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `created_at` datetime(6) NOT NULL,
  `updated_at` datetime(6) DEFAULT NULL,
  `deleted` tinyint(1) NOT NULL DEFAULT '0',
  `client_event_id` varchar(100) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `sync_batch_id` bigint DEFAULT NULL,
  `received_at` datetime(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_safety_driver_client_event` (`driver_id`,`client_event_id`),
  KEY `fk_safety_trip` (`trip_id`),
  KEY `fk_safety_handled_by` (`handled_by`),
  KEY `idx_safety_status_severity_created` (`status`,`severity`,`created_at`),
  KEY `idx_safety_vehicle_created` (`vehicle_id`,`created_at`),
  KEY `idx_safety_driver_created` (`driver_id`,`created_at`),
  KEY `idx_safety_type` (`event_type`),
  KEY `fk_safety_sync_batch` (`sync_batch_id`),
  KEY `idx_safety_received_at` (`received_at`),
  CONSTRAINT `fk_safety_driver` FOREIGN KEY (`driver_id`) REFERENCES `drivers` (`id`),
  CONSTRAINT `fk_safety_handled_by` FOREIGN KEY (`handled_by`) REFERENCES `users` (`id`),
  CONSTRAINT `fk_safety_sync_batch` FOREIGN KEY (`sync_batch_id`) REFERENCES `sync_batches` (`id`),
  CONSTRAINT `fk_safety_trip` FOREIGN KEY (`trip_id`) REFERENCES `trips` (`id`),
  CONSTRAINT `fk_safety_vehicle` FOREIGN KEY (`vehicle_id`) REFERENCES `vehicles` (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=19 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `safety_events`
--

LOCK TABLES `safety_events` WRITE;
/*!40000 ALTER TABLE `safety_events` DISABLE KEYS */;
INSERT INTO `safety_events` VALUES (1,'DROWSINESS','LOW',1,1,NULL,20.9719,105.7788,40,0.62,'https://demo.safefleet.vn/evidence/001.jpg','ACKNOWLEDGED',NULL,NULL,'Demo AI safety event around Hanoi','2026-07-26 23:05:48.096556','2026-07-27 00:05:48.096895',0,NULL,NULL,'2026-07-27 00:05:48.097710'),(2,'PHONE_USAGE','MEDIUM',2,2,NULL,21.0362,105.7906,41,0.64,'https://demo.safefleet.vn/evidence/002.jpg','NEW',NULL,NULL,'Demo AI safety event around Hanoi','2026-07-26 22:05:48.100044','2026-07-27 00:05:48.100181',0,NULL,NULL,'2026-07-27 00:05:48.101080'),(3,'DISTRACTION','HIGH',3,3,NULL,21.0285,105.7784,42,0.66,'https://demo.safefleet.vn/evidence/003.jpg','NEW',NULL,NULL,'Demo AI safety event around Hanoi','2026-07-26 21:05:48.102028','2026-07-27 00:05:48.102196',0,NULL,NULL,'2026-07-27 00:05:48.102887'),(4,'SPEEDING','CRITICAL',4,4,NULL,20.9902,105.8057,43,0.6799999999999999,'https://demo.safefleet.vn/evidence/004.jpg','NEW',NULL,NULL,'Demo AI safety event around Hanoi','2026-07-26 20:05:48.103592','2026-07-27 00:05:48.103703',0,NULL,NULL,'2026-07-27 00:05:48.104238'),(5,'OVER_DRIVING_TIME','LOW',5,5,NULL,21.0123,105.7621,44,0.7,'https://demo.safefleet.vn/evidence/005.jpg','ACKNOWLEDGED',NULL,NULL,'Demo AI safety event around Hanoi','2026-07-26 19:05:48.104829','2026-07-27 00:05:48.104909',0,NULL,NULL,'2026-07-27 00:05:48.105339'),(6,'ROUTE_DEVIATION','MEDIUM',6,6,NULL,21.0521,105.7353,45,0.72,'https://demo.safefleet.vn/evidence/006.jpg','NEW',NULL,NULL,'Demo AI safety event around Hanoi','2026-07-26 18:05:48.105773','2026-07-27 00:05:48.105919',0,NULL,NULL,'2026-07-27 00:05:48.106384'),(7,'ABNORMAL_STOP','HIGH',7,7,NULL,21.0379,105.7752,46,0.74,'https://demo.safefleet.vn/evidence/007.jpg','NEW',NULL,NULL,'Demo AI safety event around Hanoi','2026-07-26 17:05:48.106993','2026-07-27 00:05:48.107096',0,NULL,NULL,'2026-07-27 00:05:48.107621'),(8,'GPS_LOST','CRITICAL',8,8,NULL,21.0386,105.7465,47,0.76,'https://demo.safefleet.vn/evidence/008.jpg','NEW',NULL,NULL,'Demo AI safety event around Hanoi','2026-07-26 16:05:48.108102','2026-07-27 00:05:48.108275',0,NULL,NULL,'2026-07-27 00:05:48.108747'),(9,'FLOOD_RISK','LOW',9,9,NULL,21.0631,105.8014,48,0.78,'https://demo.safefleet.vn/evidence/009.jpg','ACKNOWLEDGED',NULL,NULL,'Demo AI safety event around Hanoi','2026-07-26 15:05:48.109140','2026-07-27 00:05:48.109290',0,NULL,NULL,'2026-07-27 00:05:48.109721'),(10,'DROWSINESS','MEDIUM',10,10,NULL,21.0348,105.8083,49,0.8,'https://demo.safefleet.vn/evidence/010.jpg','NEW',NULL,NULL,'Demo AI safety event around Hanoi','2026-07-26 14:05:48.110103','2026-07-27 00:05:48.110173',0,NULL,NULL,'2026-07-27 00:05:48.110612'),(11,'PHONE_USAGE','HIGH',11,11,NULL,20.9842,105.7954,50,0.8200000000000001,'https://demo.safefleet.vn/evidence/011.jpg','NEW',NULL,NULL,'Demo AI safety event around Hanoi','2026-07-26 13:05:48.111374','2026-07-27 00:05:48.111616',0,NULL,NULL,'2026-07-27 00:05:48.112450'),(12,'DISTRACTION','CRITICAL',12,12,NULL,21.0204,105.7821,51,0.84,'https://demo.safefleet.vn/evidence/012.jpg','NEW',NULL,NULL,'Demo AI safety event around Hanoi','2026-07-26 12:05:48.113645','2026-07-27 00:05:48.113871',0,NULL,NULL,'2026-07-27 00:05:48.114500'),(13,'SPEEDING','LOW',13,13,NULL,21.0465,105.7649,52,0.86,'https://demo.safefleet.vn/evidence/013.jpg','ACKNOWLEDGED',NULL,NULL,'Demo AI safety event around Hanoi','2026-07-26 11:05:48.115228','2026-07-27 00:05:48.115332',0,NULL,NULL,'2026-07-27 00:05:48.115910'),(14,'OVER_DRIVING_TIME','MEDIUM',14,14,NULL,21.0189,105.8121,53,0.88,'https://demo.safefleet.vn/evidence/014.jpg','NEW',NULL,NULL,'Demo AI safety event around Hanoi','2026-07-26 10:05:48.116535','2026-07-27 00:05:48.116627',0,NULL,NULL,'2026-07-27 00:05:48.117252'),(15,'ROUTE_DEVIATION','HIGH',15,15,NULL,21.0703,105.7832,54,0.9,'https://demo.safefleet.vn/evidence/015.jpg','NEW',NULL,NULL,'Demo AI safety event around Hanoi','2026-07-26 09:05:48.117746','2026-07-27 00:05:48.117832',0,NULL,NULL,'2026-07-27 00:05:48.118280'),(16,'PHONE_USAGE','HIGH',8,8,8,21.03855,105.74645,26.5,0.93,NULL,'NEW',NULL,NULL,'[E2E] phone usage detection','2026-07-27 00:07:35.082588','2026-07-27 00:07:35.082759',0,NULL,NULL,'2026-07-27 00:07:35.083623'),(17,'PHONE_USAGE','HIGH',1,1,NULL,21.0285,105.8542,36,0.95,NULL,'NEW',NULL,NULL,'Docker real API event','2026-07-27 02:07:39.009746','2026-07-27 02:07:39.013856',0,'docker-safety-1785092858727',NULL,'2026-07-27 02:07:39.009753'),(18,'DROWSINESS','HIGH',1,1,NULL,21.0278,105.8342,42.5,0.93,NULL,'NEW',NULL,NULL,'Docker MinIO persistence verification','2026-07-27 03:12:39.581993','2026-07-27 03:12:39.649486',0,'docker-evidence-96cea6a3520343c6830c288c21f37115',NULL,'2026-07-27 03:12:39.582003');
/*!40000 ALTER TABLE `safety_events` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `sync_batch_items`
--

DROP TABLE IF EXISTS `sync_batch_items`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `sync_batch_items` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `sync_batch_id` bigint NOT NULL,
  `item_index` int NOT NULL,
  `client_event_id` varchar(100) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `item_type` varchar(40) COLLATE utf8mb4_unicode_ci NOT NULL,
  `item_status` varchar(30) COLLATE utf8mb4_unicode_ci NOT NULL,
  `entity_id` bigint DEFAULT NULL,
  `error_message` varchar(500) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `created_at` datetime(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_sync_batch_item_index` (`sync_batch_id`,`item_index`),
  UNIQUE KEY `uk_sync_batch_item_event` (`sync_batch_id`,`client_event_id`),
  KEY `idx_sync_batch_items_batch` (`sync_batch_id`),
  CONSTRAINT `fk_sync_batch_items_batch` FOREIGN KEY (`sync_batch_id`) REFERENCES `sync_batches` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `sync_batch_items`
--

LOCK TABLES `sync_batch_items` WRITE;
/*!40000 ALTER TABLE `sync_batch_items` DISABLE KEYS */;
/*!40000 ALTER TABLE `sync_batch_items` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `sync_batches`
--

DROP TABLE IF EXISTS `sync_batches`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `sync_batches` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `batch_uuid` varchar(100) COLLATE utf8mb4_unicode_ci NOT NULL,
  `user_id` bigint NOT NULL,
  `device_id` bigint DEFAULT NULL,
  `item_count` int NOT NULL DEFAULT '0',
  `accepted_count` int NOT NULL DEFAULT '0',
  `duplicate_count` int NOT NULL DEFAULT '0',
  `rejected_count` int NOT NULL DEFAULT '0',
  `status` varchar(30) COLLATE utf8mb4_unicode_ci NOT NULL,
  `error_summary` varchar(1000) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `received_at` datetime(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  `completed_at` datetime(6) DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_sync_batches_uuid` (`batch_uuid`),
  KEY `fk_sync_batches_device` (`device_id`),
  KEY `idx_sync_batches_user_received` (`user_id`,`received_at`),
  CONSTRAINT `fk_sync_batches_device` FOREIGN KEY (`device_id`) REFERENCES `mobile_devices` (`id`),
  CONSTRAINT `fk_sync_batches_user` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=3 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `sync_batches`
--

LOCK TABLES `sync_batches` WRITE;
/*!40000 ALTER TABLE `sync_batches` DISABLE KEYS */;
INSERT INTO `sync_batches` VALUES (1,'batch-7c2087bb7542',13,NULL,1,0,1,0,'COMPLETED',NULL,'2026-07-27 00:26:18.110479','2026-07-27 00:26:18.200022');
/*!40000 ALTER TABLE `sync_batches` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `system_settings`
--

DROP TABLE IF EXISTS `system_settings`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `system_settings` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `setting_key` varchar(100) COLLATE utf8mb4_unicode_ci NOT NULL,
  `setting_group` varchar(40) COLLATE utf8mb4_unicode_ci NOT NULL,
  `setting_value` text COLLATE utf8mb4_unicode_ci NOT NULL,
  `value_type` varchar(30) COLLATE utf8mb4_unicode_ci NOT NULL,
  `description` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `updated_by` bigint DEFAULT NULL,
  `created_at` datetime(6) NOT NULL,
  `updated_at` datetime(6) DEFAULT NULL,
  `deleted` tinyint(1) NOT NULL DEFAULT '0',
  PRIMARY KEY (`id`),
  UNIQUE KEY `setting_key` (`setting_key`),
  KEY `fk_system_settings_updated_by` (`updated_by`),
  KEY `idx_system_settings_group` (`setting_group`),
  CONSTRAINT `fk_system_settings_updated_by` FOREIGN KEY (`updated_by`) REFERENCES `users` (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=10 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `system_settings`
--

LOCK TABLES `system_settings` WRITE;
/*!40000 ALTER TABLE `system_settings` DISABLE KEYS */;
INSERT INTO `system_settings` VALUES (1,'driving.max_continuous_minutes','DRIVING_TIME','240','INTEGER','Maximum continuous driving time in minutes',NULL,'2026-07-26 23:59:54.398934','2026-07-26 23:59:54.398934',0),(2,'driving.warn_1_minutes','DRIVING_TIME','180','INTEGER','First early warning after 3 hours',NULL,'2026-07-26 23:59:54.398934','2026-07-26 23:59:54.398934',0),(3,'driving.warn_2_minutes','DRIVING_TIME','210','INTEGER','Second early warning after 3 hours 30 minutes',NULL,'2026-07-26 23:59:54.398934','2026-07-26 23:59:54.398934',0),(4,'driving.critical_minutes','DRIVING_TIME','230','INTEGER','Critical warning after 3 hours 50 minutes',NULL,'2026-07-26 23:59:54.398934','2026-07-26 23:59:54.398934',0),(5,'flood.expiration_minutes','FLOOD','180','INTEGER','Flood report expiration time in minutes',NULL,'2026-07-26 23:59:54.398934','2026-07-26 23:59:54.398934',0),(6,'ai.drowsiness_threshold','AI_ALERT','0.75','DECIMAL','Drowsiness AI confidence threshold',NULL,'2026-07-26 23:59:54.398934','2026-07-26 23:59:54.398934',0),(7,'sos.escalation_minutes','SOS_ESCALATION','5','INTEGER','Minutes before SOS escalation',NULL,'2026-07-26 23:59:54.398934','2026-07-26 23:59:54.398934',0),(8,'map.default_center','MAP','{\"lat\":21.0278,\"lng\":105.8342}','JSON','Default Hanoi map center',NULL,'2026-07-26 23:59:54.398934','2026-07-26 23:59:54.398934',0),(9,'notification.realtime_enabled','NOTIFICATION','true','BOOLEAN','Enable realtime notifications',NULL,'2026-07-26 23:59:54.398934','2026-07-26 23:59:54.398934',0);
/*!40000 ALTER TABLE `system_settings` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `telemetry_logs`
--

DROP TABLE IF EXISTS `telemetry_logs`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `telemetry_logs` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `vehicle_id` bigint NOT NULL,
  `driver_id` bigint DEFAULT NULL,
  `trip_id` bigint DEFAULT NULL,
  `lat` double NOT NULL,
  `lng` double NOT NULL,
  `speed` double DEFAULT NULL,
  `heading` double DEFAULT NULL,
  `battery_level` int DEFAULT NULL,
  `gps_status` varchar(30) COLLATE utf8mb4_unicode_ci NOT NULL,
  `created_at` datetime(6) NOT NULL,
  `client_event_id` varchar(100) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `sync_batch_id` bigint DEFAULT NULL,
  `recorded_at` datetime(6) DEFAULT NULL,
  `received_at` datetime(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_telemetry_driver_client_event` (`driver_id`,`client_event_id`),
  KEY `idx_telemetry_vehicle_created` (`vehicle_id`,`created_at`),
  KEY `idx_telemetry_trip_created` (`trip_id`,`created_at`),
  KEY `idx_telemetry_driver_created` (`driver_id`,`created_at`),
  KEY `fk_telemetry_sync_batch` (`sync_batch_id`),
  KEY `idx_telemetry_received_at` (`received_at`),
  CONSTRAINT `fk_telemetry_driver` FOREIGN KEY (`driver_id`) REFERENCES `drivers` (`id`),
  CONSTRAINT `fk_telemetry_sync_batch` FOREIGN KEY (`sync_batch_id`) REFERENCES `sync_batches` (`id`),
  CONSTRAINT `fk_telemetry_trip` FOREIGN KEY (`trip_id`) REFERENCES `trips` (`id`),
  CONSTRAINT `fk_telemetry_vehicle` FOREIGN KEY (`vehicle_id`) REFERENCES `vehicles` (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=3 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `telemetry_logs`
--

LOCK TABLES `telemetry_logs` WRITE;
/*!40000 ALTER TABLE `telemetry_logs` DISABLE KEYS */;
INSERT INTO `telemetry_logs` VALUES (1,8,8,8,21.03855,105.74645,26.5,92,81,'GOOD','2026-07-27 00:07:34.977774',NULL,NULL,NULL,'2026-07-27 00:07:34.980100'),(2,8,8,8,21.03861,105.74651,24.5,92,78,'GOOD','2026-07-27 00:26:18.000000','e2e-7c2087bb7542',1,'2026-07-27 00:26:18.000000','2026-07-27 00:26:18.129342');
/*!40000 ALTER TABLE `telemetry_logs` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `trip_timelines`
--

DROP TABLE IF EXISTS `trip_timelines`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `trip_timelines` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `trip_id` bigint NOT NULL,
  `action` varchar(80) COLLATE utf8mb4_unicode_ci NOT NULL,
  `actor_id` bigint DEFAULT NULL,
  `note` varchar(500) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `created_at` datetime(6) NOT NULL,
  PRIMARY KEY (`id`),
  KEY `fk_trip_timelines_actor` (`actor_id`),
  KEY `idx_trip_timelines_trip_created` (`trip_id`,`created_at`),
  CONSTRAINT `fk_trip_timelines_actor` FOREIGN KEY (`actor_id`) REFERENCES `users` (`id`),
  CONSTRAINT `fk_trip_timelines_trip` FOREIGN KEY (`trip_id`) REFERENCES `trips` (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=10 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `trip_timelines`
--

LOCK TABLES `trip_timelines` WRITE;
/*!40000 ALTER TABLE `trip_timelines` DISABLE KEYS */;
INSERT INTO `trip_timelines` VALUES (1,8,'STARTED',13,'[E2E Docker] start','2026-07-27 00:26:18.241198'),(2,8,'PAUSED',13,'[E2E Docker] pause','2026-07-27 00:26:18.300844'),(3,8,'RESUMED',13,'[E2E Docker] resume','2026-07-27 00:26:18.355727'),(4,8,'COMPLETED',13,'[E2E Docker] complete','2026-07-27 00:26:18.403546'),(5,11,'CREATED',1,'Trip created','2026-07-27 03:23:15.078482'),(6,11,'ASSIGNED',1,'Trip assigned at creation','2026-07-27 03:23:15.092506'),(7,11,'ACCEPTED',6,'Docker idempotency acceptance','2026-07-27 03:23:15.164416'),(8,11,'STARTED',6,'Start once','2026-07-27 03:23:15.494465'),(9,11,'COMPLETED',6,'Complete once','2026-07-27 03:23:15.712752');
/*!40000 ALTER TABLE `trip_timelines` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `trips`
--

DROP TABLE IF EXISTS `trips`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `trips` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `trip_code` varchar(50) COLLATE utf8mb4_unicode_ci NOT NULL,
  `vehicle_id` bigint DEFAULT NULL,
  `driver_id` bigint DEFAULT NULL,
  `start_location` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL,
  `start_lat` double DEFAULT NULL,
  `start_lng` double DEFAULT NULL,
  `end_location` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL,
  `end_lat` double DEFAULT NULL,
  `end_lng` double DEFAULT NULL,
  `waypoints_json` json DEFAULT NULL,
  `planned_route_json` json DEFAULT NULL,
  `actual_route_json` json DEFAULT NULL,
  `planned_start_time` datetime(6) DEFAULT NULL,
  `actual_start_time` datetime(6) DEFAULT NULL,
  `estimated_end_time` datetime(6) DEFAULT NULL,
  `actual_end_time` datetime(6) DEFAULT NULL,
  `status` varchar(30) COLLATE utf8mb4_unicode_ci NOT NULL,
  `progress` int NOT NULL DEFAULT '0',
  `risk_level` varchar(30) COLLATE utf8mb4_unicode_ci NOT NULL,
  `cancel_reason` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `created_at` datetime(6) NOT NULL,
  `updated_at` datetime(6) DEFAULT NULL,
  `deleted` tinyint(1) NOT NULL DEFAULT '0',
  PRIMARY KEY (`id`),
  UNIQUE KEY `trip_code` (`trip_code`),
  KEY `idx_trips_status` (`status`),
  KEY `idx_trips_vehicle_status` (`vehicle_id`,`status`),
  KEY `idx_trips_driver_status` (`driver_id`,`status`),
  KEY `idx_trips_planned_start` (`planned_start_time`),
  CONSTRAINT `fk_trips_driver` FOREIGN KEY (`driver_id`) REFERENCES `drivers` (`id`),
  CONSTRAINT `fk_trips_vehicle` FOREIGN KEY (`vehicle_id`) REFERENCES `vehicles` (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=12 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `trips`
--

LOCK TABLES `trips` WRITE;
/*!40000 ALTER TABLE `trips` DISABLE KEYS */;
INSERT INTO `trips` VALUES (1,'DEMO-TRIP-001',1,1,'Ha Dong',20.9719,105.7788,'Kieu Mai',21.02,105.78,'[]','[]','[]','2026-07-22 00:05:48.078239',NULL,'2026-07-22 02:05:48.078252',NULL,'COMPLETED',100,'HIGH',NULL,'2026-07-27 00:05:48.078558','2026-07-27 00:05:48.078558',0),(2,'DEMO-TRIP-002',2,2,'Cau Giay',21.0362,105.7906,'Phu Dien',21.023,105.784,'[]','[]','[]','2026-07-23 00:05:48.082250',NULL,'2026-07-23 02:05:48.082262',NULL,'COMPLETED',100,'LOW',NULL,'2026-07-27 00:05:48.082374','2026-07-27 00:05:48.082374',0),(3,'DEMO-TRIP-003',3,3,'My Dinh',21.0285,105.7784,'Ho Tung Mau',21.026,105.788,'[]','[]','[]','2026-07-24 00:05:48.084519',NULL,'2026-07-24 02:05:48.084530',NULL,'COMPLETED',100,'LOW',NULL,'2026-07-27 00:05:48.084649','2026-07-27 00:05:48.084649',0),(4,'DEMO-TRIP-004',4,4,'Nguyen Trai',20.9902,105.8057,'Pham Van Dong',21.029,105.792,'[]','[]','[]','2026-07-25 00:05:48.086404',NULL,'2026-07-25 02:05:48.086416',NULL,'COMPLETED',100,'LOW',NULL,'2026-07-27 00:05:48.086533','2026-07-27 00:05:48.086533',0),(5,'DEMO-TRIP-005',5,5,'Dai lo Thang Long',21.0123,105.7621,'Cau Giay',21.032,105.796,'[]','[]','[]','2026-07-26 00:05:48.087649',NULL,'2026-07-26 02:05:48.087657',NULL,'IN_PROGRESS',65,'LOW',NULL,'2026-07-27 00:05:48.087743','2026-07-27 00:05:48.087743',0),(6,'DEMO-TRIP-006',6,6,'Ha Dong',21.0521,105.7353,'Kieu Mai',21.035,105.8,'[]','[]','[]','2026-07-27 00:05:48.089232',NULL,'2026-07-27 02:05:48.089241',NULL,'IN_PROGRESS',70,'HIGH',NULL,'2026-07-27 00:05:48.089319','2026-07-27 00:05:48.089319',0),(7,'DEMO-TRIP-007',7,7,'Cau Giay',21.0379,105.7752,'Phu Dien',21.038,105.804,'[]','[]','[]','2026-07-28 00:05:48.090627',NULL,'2026-07-28 02:05:48.090635',NULL,'IN_PROGRESS',75,'LOW',NULL,'2026-07-27 00:05:48.090728','2026-07-27 00:05:48.090728',0),(8,'DEMO-TRIP-008',8,8,'My Dinh',21.0386,105.7465,'Ho Tung Mau',21.041,105.808,'[]','[]','[]','2026-07-29 00:05:48.092084','2026-07-27 00:26:18.239819','2026-07-29 02:05:48.092093','2026-07-27 00:26:18.402416','COMPLETED',100,'LOW',NULL,'2026-07-27 00:05:48.092171','2026-07-27 00:26:18.420257',0),(9,'DEMO-TRIP-009',9,9,'Nguyen Trai',21.0631,105.8014,'Pham Van Dong',21.044,105.812,'[]','[]','[]','2026-07-30 00:05:48.093459',NULL,'2026-07-30 02:05:48.093517',NULL,'ASSIGNED',0,'LOW',NULL,'2026-07-27 00:05:48.093628','2026-07-27 00:05:48.093628',0),(10,'DEMO-TRIP-010',10,10,'Dai lo Thang Long',21.0348,105.8083,'Cau Giay',21.047,105.816,'[]','[]','[]','2026-07-31 00:05:48.095010',NULL,'2026-07-31 02:05:48.095022',NULL,'ASSIGNED',0,'LOW',NULL,'2026-07-27 00:05:48.095124','2026-07-27 00:05:48.095124',0),(11,'TRIP-20260727032315-7529',1,1,'SafeFleet Docker Depot',21.0278,105.8342,'SafeFleet Docker Destination',21.045,105.82,NULL,NULL,NULL,'2026-07-27 03:33:14.000000','2026-07-27 03:23:15.491337','2026-07-27 05:23:14.000000','2026-07-27 03:23:15.711103','COMPLETED',100,'LOW',NULL,'2026-07-27 03:23:15.063896','2026-07-27 03:23:15.744496',0);
/*!40000 ALTER TABLE `trips` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `users`
--

DROP TABLE IF EXISTS `users`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `users` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `username` varchar(80) COLLATE utf8mb4_unicode_ci NOT NULL,
  `email` varchar(120) COLLATE utf8mb4_unicode_ci NOT NULL,
  `password_hash` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL,
  `full_name` varchar(150) COLLATE utf8mb4_unicode_ci NOT NULL,
  `phone` varchar(20) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `status` varchar(30) COLLATE utf8mb4_unicode_ci NOT NULL,
  `role_id` bigint NOT NULL,
  `created_at` datetime(6) NOT NULL,
  `updated_at` datetime(6) DEFAULT NULL,
  `deleted` tinyint(1) NOT NULL DEFAULT '0',
  PRIMARY KEY (`id`),
  UNIQUE KEY `username` (`username`),
  UNIQUE KEY `email` (`email`),
  KEY `fk_users_role` (`role_id`),
  KEY `idx_users_email` (`email`),
  KEY `idx_users_status` (`status`),
  CONSTRAINT `fk_users_role` FOREIGN KEY (`role_id`) REFERENCES `roles` (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=21 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `users`
--

LOCK TABLES `users` WRITE;
/*!40000 ALTER TABLE `users` DISABLE KEYS */;
INSERT INTO `users` VALUES (1,'admin','admin@safefleet.vn','$2a$10$DGqfDJFNv7FhU5ULGWHFWOaoRGnN/TssPI2S2ve345dL2Zjm1fKJu','Quan tri he thong','0901000001','ACTIVE',1,'2026-07-27 00:05:46.703390','2026-07-27 00:05:46.703390',0),(2,'manager','manager@safefleet.vn','$2a$10$zk5jjg0QBAgQhvrJATFURurvaOTYwsQgyW.yMngQM45RwEUTsis1O','Quan ly doi xe','0901000002','ACTIVE',2,'2026-07-27 00:05:46.825964','2026-07-27 00:05:46.825964',0),(3,'dispatcher','dispatcher@safefleet.vn','$2a$10$taCb1faAveJ4d2TwZP732ebqJueWUXNZHVNYjfugnCId/HnzlwJw6','Dieu phoi Ha Noi','0901000003','ACTIVE',3,'2026-07-27 00:05:46.898150','2026-07-27 00:05:46.898150',0),(4,'safety','safety@safefleet.vn','$2a$10$/JyKmOuZh56iQMVl9rxpNeJarYL55TQia89sRWP7252Ly/XjduAgO','Nhan vien an toan','0901000004','ACTIVE',4,'2026-07-27 00:05:46.966261','2026-07-27 00:05:46.966261',0),(5,'rescue','rescue@safefleet.vn','$2a$10$a9sCKFWA8kYGeXKqZfIqq.W5.Y09aBGbKSibr2ig0kw9zOYHFd.dm','Doi cuu ho','0901000005','ACTIVE',5,'2026-07-27 00:05:47.033099','2026-07-27 00:05:47.033099',0),(6,'driver01','driver01@safefleet.vn','$2a$10$Silp7KcP8L9qV8N/bA.tuOw0sRcrPzZQtpPM8.pIv5FHnV2oHarhy','Nguyen Van An','0988000001','ACTIVE',6,'2026-07-27 00:05:47.097512','2026-07-27 00:05:47.097512',0),(7,'driver02','driver02@safefleet.vn','$2a$10$Rhhp2EX5Y1TIF/.DtusL7.fni92kE7roprKnhpXcnf6GSdBoR7iyG','Tran Minh Duc','0988000002','ACTIVE',6,'2026-07-27 00:05:47.169696','2026-07-27 00:05:47.169696',0),(8,'driver03','driver03@safefleet.vn','$2a$10$FksAfuVcbTyTzMg8dHgUgOyjINnFfCyh0pnzF00OZZXS5lvgvMdFu','Le Quang Huy','0988000003','ACTIVE',6,'2026-07-27 00:05:47.237663','2026-07-27 00:05:47.237663',0),(9,'driver04','driver04@safefleet.vn','$2a$10$aB1N9NYpyDCtwKroTOpPo.0wy8yDfKGQ5dlafVq1ZBfQfFx72V4aK','Pham Tuan Anh','0988000004','ACTIVE',6,'2026-07-27 00:05:47.303491','2026-07-27 00:05:47.303491',0),(10,'driver05','driver05@safefleet.vn','$2a$10$zyRyIpt72o5stmAUcEswr.EJEp4OBOjqh/xSsfyHTeMpU9wVFaQ1q','Do Van Nam','0988000005','ACTIVE',6,'2026-07-27 00:05:47.369521','2026-07-27 00:05:47.369521',0),(11,'driver06','driver06@safefleet.vn','$2a$10$N08Kt9P3BD8kcKK7zKxKSeObJ3VWNDcoayyYqULh9gboQxpnAZB3q','Hoang Manh Cuong','0988000006','ACTIVE',6,'2026-07-27 00:05:47.436050','2026-07-27 00:05:47.436050',0),(12,'driver07','driver07@safefleet.vn','$2a$10$rFoH7EMhU55WUGc7fFmAie6MRaVUSpxG49dPE2Ld5de3DXjUUCzJe','Vu Thanh Long','0988000007','ACTIVE',6,'2026-07-27 00:05:47.502157','2026-07-27 00:05:47.502157',0),(13,'driver08','driver08@safefleet.vn','$2a$10$HxADtdTRB4oIT9GU6cXXuOMPHpQhlGl.SKN8TTrbumSw8HXAfqvtu','Bui Hai Dang','0988000008','ACTIVE',6,'2026-07-27 00:05:47.564609','2026-07-27 00:05:47.564609',0),(14,'driver09','driver09@safefleet.vn','$2a$10$qkUPmvYF9QtPT7Xt/.EPX.ZJ1bJvBGw6XcbjqLROgr8/8wiLRlgkC','Dang Quoc Viet','0988000009','ACTIVE',6,'2026-07-27 00:05:47.629161','2026-07-27 00:05:47.629161',0),(15,'driver10','driver10@safefleet.vn','$2a$10$ZkOJLQMLCndXrl5SZIgn5OOIHphDXF9yviSXaCRdNzSUpwvy6eEzO','Phan Van Son','0988000010','ACTIVE',6,'2026-07-27 00:05:47.696665','2026-07-27 00:05:47.696665',0),(16,'driver11','driver11@safefleet.vn','$2a$10$mSaMt1.WlKN0J0sYnej.seWmTa1pZuh3.DYvkk0z52n.Qmt/G65Gu','Nguyen Duc Thang','0988000011','ACTIVE',6,'2026-07-27 00:05:47.761577','2026-07-27 00:05:47.761577',0),(17,'driver12','driver12@safefleet.vn','$2a$10$uf89A./3Tvdhnfxvwv9IwOvA.vA02dnVmT6g/Es1OjD5KfaxpwMiW','Tran Bao Khanh','0988000012','ACTIVE',6,'2026-07-27 00:05:47.826971','2026-07-27 00:05:47.826971',0),(18,'driver13','driver13@safefleet.vn','$2a$10$NYgnv/Y2cmedb2RhCBQY5Oz.Uc1xnctr.2gEci3GenAJF8Py0wujC','Le Thanh Tung','0988000013','ACTIVE',6,'2026-07-27 00:05:47.890380','2026-07-27 00:05:47.890380',0),(19,'driver14','driver14@safefleet.vn','$2a$10$YYsRukUEyZDtVOWKEEISy.GS62BJ91FydTlIL4Cq7jxGKUvzLKkX.','Pham Dinh Khoa','0988000014','ACTIVE',6,'2026-07-27 00:05:47.954927','2026-07-27 00:05:47.954927',0),(20,'driver15','driver15@safefleet.vn','$2a$10$kSUJtzhE0xaISshML1IydeOpqPs9uvy810k69Ql9wgqHL4GwF2j7K','Do Minh Quan','0988000015','ACTIVE',6,'2026-07-27 00:05:48.020460','2026-07-27 00:05:48.020460',0);
/*!40000 ALTER TABLE `users` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `vehicles`
--

DROP TABLE IF EXISTS `vehicles`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `vehicles` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `plate_number` varchar(30) COLLATE utf8mb4_unicode_ci NOT NULL,
  `vehicle_type` varchar(30) COLLATE utf8mb4_unicode_ci NOT NULL,
  `brand` varchar(80) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `model` varchar(80) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `manufacture_year` int DEFAULT NULL,
  `load_capacity` decimal(10,2) DEFAULT NULL,
  `seat_count` int DEFAULT NULL,
  `fuel_type` varchar(30) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `status` varchar(30) COLLATE utf8mb4_unicode_ci NOT NULL,
  `current_driver_id` bigint DEFAULT NULL,
  `gps_device_id` bigint DEFAULT NULL,
  `camera_device_id` bigint DEFAULT NULL,
  `inspection_expired_at` date DEFAULT NULL,
  `insurance_expired_at` date DEFAULT NULL,
  `last_lat` double DEFAULT NULL,
  `last_lng` double DEFAULT NULL,
  `last_speed` double DEFAULT NULL,
  `last_updated_at` datetime(6) DEFAULT NULL,
  `created_at` datetime(6) NOT NULL,
  `updated_at` datetime(6) DEFAULT NULL,
  `deleted` tinyint(1) NOT NULL DEFAULT '0',
  PRIMARY KEY (`id`),
  UNIQUE KEY `plate_number` (`plate_number`),
  KEY `idx_vehicles_plate_number` (`plate_number`),
  KEY `idx_vehicles_type_status` (`vehicle_type`,`status`),
  KEY `idx_vehicles_status` (`status`),
  KEY `fk_vehicles_current_driver` (`current_driver_id`),
  KEY `fk_vehicles_gps_device` (`gps_device_id`),
  KEY `fk_vehicles_camera_device` (`camera_device_id`),
  CONSTRAINT `fk_vehicles_camera_device` FOREIGN KEY (`camera_device_id`) REFERENCES `devices` (`id`),
  CONSTRAINT `fk_vehicles_current_driver` FOREIGN KEY (`current_driver_id`) REFERENCES `drivers` (`id`),
  CONSTRAINT `fk_vehicles_gps_device` FOREIGN KEY (`gps_device_id`) REFERENCES `devices` (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=21 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `vehicles`
--

LOCK TABLES `vehicles` WRITE;
/*!40000 ALTER TABLE `vehicles` DISABLE KEYS */;
INSERT INTO `vehicles` VALUES (1,'30H-100.01','TRUCK','Hyundai','Mighty',2020,1200.00,3,'ELECTRIC','AVAILABLE',1,1,7,'2027-01-27','2027-04-27',20.9719,105.7788,0,'2026-07-27 00:05:48.038250','2026-07-27 00:05:48.038518','2026-07-27 03:23:15.744693',0),(2,'30H-101.02','VAN','Thaco','Frontier',2021,1450.00,3,'DIESEL','AVAILABLE',2,2,8,'2027-01-28','2027-04-28',21.0362,105.7906,36,'2026-07-27 00:00:48.040953','2026-07-27 00:05:48.041082','2026-07-27 00:05:48.041082',0),(3,'30H-102.03','BUS','Toyota','Hiace',2022,1700.00,29,'DIESEL','AVAILABLE',3,3,NULL,'2027-01-29','2027-04-29',21.0285,105.7784,37,'2026-07-26 23:55:48.043058','2026-07-27 00:05:48.043347','2026-07-27 00:05:48.043347',0),(4,'30H-103.04','TRUCK','Ford','Transit',2023,1950.00,3,'DIESEL','AVAILABLE',4,4,NULL,'2027-01-30','2027-04-30',20.9902,105.8057,38,'2026-07-26 23:50:48.045379','2026-07-27 00:05:48.045498','2026-07-27 00:05:48.045498',0),(5,'30H-104.05','VAN','Isuzu','NQR',2024,2200.00,3,'ELECTRIC','AVAILABLE',5,5,NULL,'2027-01-31','2027-05-01',21.0123,105.7621,39,'2026-07-26 23:45:48.047370','2026-07-27 00:05:48.047524','2026-07-27 00:05:48.047524',0),(6,'30H-105.06','BUS','Hyundai','Mighty',2020,2450.00,29,'DIESEL','AVAILABLE',6,6,NULL,'2027-02-01','2027-05-02',21.0521,105.7353,0,'2026-07-26 23:40:48.049283','2026-07-27 00:05:48.049376','2026-07-27 00:05:48.049376',0),(7,'30H-106.07','TRUCK','Thaco','Frontier',2021,2700.00,3,'DIESEL','AVAILABLE',7,NULL,NULL,'2027-02-02','2027-05-03',21.0379,105.7752,41,'2026-07-26 23:35:48.051128','2026-07-27 00:05:48.051253','2026-07-27 00:05:48.051253',0),(8,'30H-107.08','VAN','Toyota','Hiace',2022,2950.00,3,'DIESEL','AVAILABLE',8,NULL,NULL,'2027-02-03','2027-05-04',21.03861,105.74651,24.5,'2026-07-27 00:26:18.000000','2026-07-27 00:05:48.052808','2026-07-27 00:26:18.420400',0),(9,'30H-108.09','BUS','Ford','Transit',2023,3200.00,29,'ELECTRIC','AVAILABLE',9,NULL,NULL,'2027-02-04','2027-05-05',21.0631,105.8014,43,'2026-07-26 23:25:48.054607','2026-07-27 00:05:48.054863','2026-07-27 00:05:48.054863',0),(10,'30H-109.10','TRUCK','Isuzu','NQR',2024,3450.00,3,'DIESEL','OFFLINE',10,NULL,NULL,'2027-02-05','2027-05-06',21.0348,105.8083,44,'2026-07-26 23:20:48.056502','2026-07-27 00:05:48.056617','2026-07-27 00:05:48.056617',0),(11,'30H-110.11','VAN','Hyundai','Mighty',2020,3700.00,3,'DIESEL','AVAILABLE',11,NULL,NULL,'2027-02-06','2027-05-07',20.9842,105.7954,0,'2026-07-26 23:15:48.058627','2026-07-27 00:05:48.058805','2026-07-27 00:05:48.058805',0),(12,'30H-111.12','BUS','Thaco','Frontier',2021,3950.00,29,'DIESEL','AVAILABLE',12,NULL,NULL,'2027-02-07','2027-05-08',21.0204,105.7821,46,'2026-07-26 23:10:48.060424','2026-07-27 00:05:48.060533','2026-07-27 00:05:48.060533',0),(13,'30H-112.13','TRUCK','Toyota','Hiace',2022,4200.00,3,'ELECTRIC','AVAILABLE',13,NULL,NULL,'2027-02-08','2027-05-09',21.0465,105.7649,47,'2026-07-26 23:05:48.062207','2026-07-27 00:05:48.062394','2026-07-27 00:05:48.062394',0),(14,'30H-113.14','VAN','Ford','Transit',2023,4450.00,3,'DIESEL','AVAILABLE',14,NULL,NULL,'2027-02-09','2027-05-10',21.0189,105.8121,48,'2026-07-26 23:00:48.065633','2026-07-27 00:05:48.065872','2026-07-27 00:05:48.065872',0),(15,'30H-114.15','BUS','Isuzu','NQR',2024,4700.00,29,'DIESEL','AVAILABLE',15,NULL,NULL,'2027-02-10','2027-05-11',21.0703,105.7832,49,'2026-07-26 22:55:48.068191','2026-07-27 00:05:48.068562','2026-07-27 00:05:48.068562',0),(16,'30H-115.16','TRUCK','Hyundai','Mighty',2020,4950.00,3,'DIESEL','AVAILABLE',NULL,NULL,NULL,'2027-02-11','2027-05-12',20.9977,105.8321,0,'2026-07-26 22:50:48.070302','2026-07-27 00:05:48.070417','2026-07-27 00:05:48.070417',0),(17,'30H-116.17','VAN','Thaco','Frontier',2021,5200.00,3,'ELECTRIC','AVAILABLE',NULL,NULL,NULL,'2027-02-12','2027-05-13',21.0242,105.8211,51,'2026-07-26 22:45:48.072153','2026-07-27 00:05:48.072326','2026-07-27 00:05:48.072326',0),(18,'30H-117.18','BUS','Toyota','Hiace',2022,5450.00,29,'DIESEL','AVAILABLE',NULL,NULL,NULL,'2027-02-13','2027-05-14',21.0567,105.8123,52,'2026-07-26 22:40:48.073595','2026-07-27 00:05:48.073749','2026-07-27 00:05:48.073749',0),(19,'30H-118.19','TRUCK','Ford','Transit',2023,5700.00,3,'DIESEL','AVAILABLE',NULL,NULL,NULL,'2027-02-14','2027-05-15',20.9634,105.7945,53,'2026-07-26 22:35:48.075172','2026-07-27 00:05:48.075308','2026-07-27 00:05:48.075308',0),(20,'30H-119.20','VAN','Isuzu','NQR',2024,5950.00,3,'DIESEL','AVAILABLE',NULL,NULL,NULL,'2027-02-15','2027-05-16',21.0412,105.7305,54,'2026-07-26 22:30:48.076791','2026-07-27 00:05:48.076878','2026-07-27 00:05:48.076878',0);
/*!40000 ALTER TABLE `vehicles` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Dumping events for database 'safefleet'
--

--
-- Dumping routines for database 'safefleet'
--
/*!40103 SET TIME_ZONE=@OLD_TIME_ZONE */;

/*!40101 SET SQL_MODE=@OLD_SQL_MODE */;
/*!40014 SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS */;
/*!40014 SET UNIQUE_CHECKS=@OLD_UNIQUE_CHECKS */;
/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
/*!40111 SET SQL_NOTES=@OLD_SQL_NOTES */;

-- Dump completed on 2026-07-27  9:56:07
