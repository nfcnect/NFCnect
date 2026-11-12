CREATE TABLE `point_checks` (
	`id` text PRIMARY KEY NOT NULL,
	`business_id` text NOT NULL,
	`membership_id` text NOT NULL,
	`expected_version` integer NOT NULL,
	`expired_points` integer NOT NULL,
	`details` text NOT NULL,
	`as_of` text NOT NULL,
	`created_at` text DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now')) NOT NULL,
	FOREIGN KEY (`business_id`) REFERENCES `businesses`(`id`) ON UPDATE no action ON DELETE no action,
	FOREIGN KEY (`membership_id`) REFERENCES `memberships`(`id`) ON UPDATE no action ON DELETE no action
);
--> statement-breakpoint
CREATE INDEX `checks_membership` ON `point_checks` (`business_id`,`membership_id`);--> statement-breakpoint
ALTER TABLE `businesses` ADD `validity_days` integer;--> statement-breakpoint
ALTER TABLE `cancellations` ADD `validity_days` integer;--> statement-breakpoint
ALTER TABLE `purchases` ADD `validity_days` integer;