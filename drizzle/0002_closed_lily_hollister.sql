CREATE TABLE `privacy_redactions` (
	`id` text PRIMARY KEY NOT NULL,
	`business_id` text NOT NULL,
	`membership_id` text NOT NULL,
	`actor_id` text NOT NULL,
	`created_at` text DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now')) NOT NULL,
	FOREIGN KEY (`business_id`) REFERENCES `businesses`(`id`) ON UPDATE no action ON DELETE no action,
	FOREIGN KEY (`membership_id`) REFERENCES `memberships`(`id`) ON UPDATE no action ON DELETE no action
);
--> statement-breakpoint
CREATE UNIQUE INDEX `privacy_redactions_membership_id_unique` ON `privacy_redactions` (`membership_id`);--> statement-breakpoint
ALTER TABLE `memberships` ADD `anonymized_at` text;