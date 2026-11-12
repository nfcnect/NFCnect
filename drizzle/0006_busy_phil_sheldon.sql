ALTER TABLE `purchases` ADD `entry_method` text DEFAULT 'receipt' NOT NULL;--> statement-breakpoint
ALTER TABLE `purchases` ADD `backup_reason` text;
