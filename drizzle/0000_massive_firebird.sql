CREATE TABLE `audit` (
	`id` text PRIMARY KEY NOT NULL,
	`business_id` text NOT NULL,
	`actor_id` text NOT NULL,
	`event` text NOT NULL,
	`target_id` text NOT NULL,
	`detail` text DEFAULT '' NOT NULL,
	`created_at` text DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now')) NOT NULL,
	FOREIGN KEY (`business_id`) REFERENCES `businesses`(`id`) ON UPDATE no action ON DELETE no action
);
--> statement-breakpoint
CREATE INDEX `audit_business` ON `audit` (`business_id`,`created_at`);--> statement-breakpoint
CREATE TABLE `businesses` (
	`id` text PRIMARY KEY NOT NULL,
	`name` text NOT NULL,
	`step_centavos` integer DEFAULT 5000 NOT NULL,
	`rule_version` integer DEFAULT 1 NOT NULL,
	`created_at` text DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now')) NOT NULL,
	CONSTRAINT "step_positive" CHECK("businesses"."step_centavos">0)
);
--> statement-breakpoint
CREATE TABLE `cancellations` (
	`id` text PRIMARY KEY NOT NULL,
	`business_id` text NOT NULL,
	`redemption_id` text NOT NULL,
	`actor_id` text NOT NULL,
	`reason` text NOT NULL,
	`created_at` text DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now')) NOT NULL,
	FOREIGN KEY (`business_id`) REFERENCES `businesses`(`id`) ON UPDATE no action ON DELETE no action,
	FOREIGN KEY (`redemption_id`) REFERENCES `redemptions`(`id`) ON UPDATE no action ON DELETE no action
);
--> statement-breakpoint
CREATE UNIQUE INDEX `cancellations_redemption_id_unique` ON `cancellations` (`redemption_id`);--> statement-breakpoint
CREATE TABLE `cards` (
	`id` text PRIMARY KEY NOT NULL,
	`business_id` text NOT NULL,
	`membership_id` text NOT NULL,
	`token_hash` text NOT NULL,
	`status` text DEFAULT 'active' NOT NULL,
	`created_at` text DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now')) NOT NULL,
	FOREIGN KEY (`business_id`) REFERENCES `businesses`(`id`) ON UPDATE no action ON DELETE no action,
	FOREIGN KEY (`membership_id`) REFERENCES `memberships`(`id`) ON UPDATE no action ON DELETE no action,
	CONSTRAINT "card_status" CHECK("cards"."status" in ('active','revoked'))
);
--> statement-breakpoint
CREATE UNIQUE INDEX `cards_token_hash_unique` ON `cards` (`token_hash`);--> statement-breakpoint
CREATE INDEX `cards_membership` ON `cards` (`membership_id`);--> statement-breakpoint
CREATE TABLE `employees` (
	`id` text PRIMARY KEY NOT NULL,
	`business_id` text NOT NULL,
	`user_id` text NOT NULL,
	`email` text NOT NULL,
	`role` text NOT NULL,
	`status` text DEFAULT 'active' NOT NULL,
	`created_at` text DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now')) NOT NULL,
	FOREIGN KEY (`business_id`) REFERENCES `businesses`(`id`) ON UPDATE no action ON DELETE no action,
	CONSTRAINT "staff_role" CHECK("employees"."role" in ('admin','cashier')),
	CONSTRAINT "staff_status" CHECK("employees"."status" in ('active','disabled'))
);
--> statement-breakpoint
CREATE UNIQUE INDEX `staff_user_business` ON `employees` (`business_id`,`user_id`);--> statement-breakpoint
CREATE TABLE `fulfillments` (
	`id` text PRIMARY KEY NOT NULL,
	`business_id` text NOT NULL,
	`redemption_id` text NOT NULL,
	`actor_id` text NOT NULL,
	`created_at` text DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now')) NOT NULL,
	FOREIGN KEY (`business_id`) REFERENCES `businesses`(`id`) ON UPDATE no action ON DELETE no action,
	FOREIGN KEY (`redemption_id`) REFERENCES `redemptions`(`id`) ON UPDATE no action ON DELETE no action
);
--> statement-breakpoint
CREATE UNIQUE INDEX `fulfillments_redemption_id_unique` ON `fulfillments` (`redemption_id`);--> statement-breakpoint
CREATE TABLE `invitations` (
	`id` text PRIMARY KEY NOT NULL,
	`business_id` text NOT NULL,
	`membership_id` text,
	`email` text NOT NULL,
	`kind` text NOT NULL,
	`role` text,
	`token_hash` text NOT NULL,
	`expires_at` text NOT NULL,
	`used_at` text,
	`claimed_user_id` text,
	`created_at` text DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now')) NOT NULL,
	FOREIGN KEY (`business_id`) REFERENCES `businesses`(`id`) ON UPDATE no action ON DELETE no action,
	FOREIGN KEY (`membership_id`) REFERENCES `memberships`(`id`) ON UPDATE no action ON DELETE no action,
	CONSTRAINT "invitation_kind" CHECK("invitations"."kind" in ('customer','employee'))
);
--> statement-breakpoint
CREATE UNIQUE INDEX `invitations_token_hash_unique` ON `invitations` (`token_hash`);--> statement-breakpoint
CREATE TABLE `ledger` (
	`id` text PRIMARY KEY NOT NULL,
	`business_id` text NOT NULL,
	`membership_id` text NOT NULL,
	`delta` integer NOT NULL,
	`kind` text NOT NULL,
	`source_id` text NOT NULL,
	`created_at` text DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now')) NOT NULL,
	FOREIGN KEY (`business_id`) REFERENCES `businesses`(`id`) ON UPDATE no action ON DELETE no action,
	FOREIGN KEY (`membership_id`) REFERENCES `memberships`(`id`) ON UPDATE no action ON DELETE no action
);
--> statement-breakpoint
CREATE UNIQUE INDEX `ledger_source` ON `ledger` (`business_id`,`kind`,`source_id`);--> statement-breakpoint
CREATE INDEX `ledger_balance` ON `ledger` (`business_id`,`membership_id`);--> statement-breakpoint
CREATE TABLE `rate_limits` (
	`key` text PRIMARY KEY NOT NULL,
	`count` integer NOT NULL,
	`expires` integer NOT NULL
);
--> statement-breakpoint
CREATE TABLE `memberships` (
	`id` text PRIMARY KEY NOT NULL,
	`business_id` text NOT NULL,
	`user_id` text,
	`display_name` text NOT NULL,
	`status` text DEFAULT 'active' NOT NULL,
	`created_at` text DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now')) NOT NULL,
	FOREIGN KEY (`business_id`) REFERENCES `businesses`(`id`) ON UPDATE no action ON DELETE no action,
	CONSTRAINT "membership_status" CHECK("memberships"."status" in ('active','suspended','closed'))
);
--> statement-breakpoint
CREATE UNIQUE INDEX `member_user_business` ON `memberships` (`business_id`,`user_id`);--> statement-breakpoint
CREATE INDEX `members_business` ON `memberships` (`business_id`);--> statement-breakpoint
CREATE TABLE `purchases` (
	`id` text PRIMARY KEY NOT NULL,
	`business_id` text NOT NULL,
	`membership_id` text NOT NULL,
	`receipt` text NOT NULL,
	`amount_centavos` integer NOT NULL,
	`step_centavos` integer NOT NULL,
	`rule_version` integer NOT NULL,
	`points` integer NOT NULL,
	`actor_id` text NOT NULL,
	`idempotency_key` text NOT NULL,
	`payload_hash` text NOT NULL,
	`created_at` text DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now')) NOT NULL,
	FOREIGN KEY (`business_id`) REFERENCES `businesses`(`id`) ON UPDATE no action ON DELETE no action,
	FOREIGN KEY (`membership_id`) REFERENCES `memberships`(`id`) ON UPDATE no action ON DELETE no action,
	CONSTRAINT "purchase_values" CHECK("purchases"."amount_centavos">0 and "purchases"."step_centavos">0 and "purchases"."points">=0)
);
--> statement-breakpoint
CREATE UNIQUE INDEX `receipt_per_business` ON `purchases` (`business_id`,`receipt`);--> statement-breakpoint
CREATE UNIQUE INDEX `purchase_idempotency` ON `purchases` (`business_id`,`idempotency_key`);--> statement-breakpoint
CREATE TABLE `redemptions` (
	`id` text PRIMARY KEY NOT NULL,
	`business_id` text NOT NULL,
	`membership_id` text NOT NULL,
	`request_id` text NOT NULL,
	`reward_id` text NOT NULL,
	`points` integer NOT NULL,
	`cost_centavos` integer NOT NULL,
	`basket_centavos` integer NOT NULL,
	`actor_id` text NOT NULL,
	`idempotency_key` text NOT NULL,
	`payload_hash` text NOT NULL,
	`created_at` text DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now')) NOT NULL,
	FOREIGN KEY (`business_id`) REFERENCES `businesses`(`id`) ON UPDATE no action ON DELETE no action,
	FOREIGN KEY (`membership_id`) REFERENCES `memberships`(`id`) ON UPDATE no action ON DELETE no action,
	FOREIGN KEY (`request_id`) REFERENCES `reward_requests`(`id`) ON UPDATE no action ON DELETE no action,
	FOREIGN KEY (`reward_id`) REFERENCES `rewards`(`id`) ON UPDATE no action ON DELETE no action
);
--> statement-breakpoint
CREATE UNIQUE INDEX `redemptions_request_id_unique` ON `redemptions` (`request_id`);--> statement-breakpoint
CREATE UNIQUE INDEX `redemption_idempotency` ON `redemptions` (`business_id`,`idempotency_key`);--> statement-breakpoint
CREATE TABLE `refunds` (
	`id` text PRIMARY KEY NOT NULL,
	`business_id` text NOT NULL,
	`purchase_id` text NOT NULL,
	`amount_centavos` integer NOT NULL,
	`actor_id` text NOT NULL,
	`reason` text NOT NULL,
	`idempotency_key` text NOT NULL,
	`payload_hash` text NOT NULL,
	`created_at` text DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now')) NOT NULL,
	FOREIGN KEY (`business_id`) REFERENCES `businesses`(`id`) ON UPDATE no action ON DELETE no action,
	FOREIGN KEY (`purchase_id`) REFERENCES `purchases`(`id`) ON UPDATE no action ON DELETE no action,
	CONSTRAINT "refund_positive" CHECK("refunds"."amount_centavos">0)
);
--> statement-breakpoint
CREATE UNIQUE INDEX `refund_idempotency` ON `refunds` (`business_id`,`idempotency_key`);--> statement-breakpoint
CREATE INDEX `refund_purchase` ON `refunds` (`purchase_id`);--> statement-breakpoint
CREATE TABLE `reward_requests` (
	`id` text PRIMARY KEY NOT NULL,
	`business_id` text NOT NULL,
	`membership_id` text NOT NULL,
	`reward_id` text NOT NULL,
	`points` integer NOT NULL,
	`requester_id` text NOT NULL,
	`idempotency_key` text NOT NULL,
	`payload_hash` text NOT NULL,
	`expires_at` text NOT NULL,
	`created_at` text DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now')) NOT NULL,
	FOREIGN KEY (`business_id`) REFERENCES `businesses`(`id`) ON UPDATE no action ON DELETE no action,
	FOREIGN KEY (`membership_id`) REFERENCES `memberships`(`id`) ON UPDATE no action ON DELETE no action,
	FOREIGN KEY (`reward_id`) REFERENCES `rewards`(`id`) ON UPDATE no action ON DELETE no action
);
--> statement-breakpoint
CREATE UNIQUE INDEX `request_idempotency` ON `reward_requests` (`business_id`,`idempotency_key`);--> statement-breakpoint
CREATE TABLE `rewards` (
	`id` text PRIMARY KEY NOT NULL,
	`business_id` text NOT NULL,
	`name` text NOT NULL,
	`points` integer NOT NULL,
	`discount_centavos` integer DEFAULT 0 NOT NULL,
	`minimum_basket_centavos` integer DEFAULT 0 NOT NULL,
	`cost_centavos` integer DEFAULT 0 NOT NULL,
	`stock` integer DEFAULT -1 NOT NULL,
	`active` integer DEFAULT 1 NOT NULL,
	`created_at` text DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now')) NOT NULL,
	FOREIGN KEY (`business_id`) REFERENCES `businesses`(`id`) ON UPDATE no action ON DELETE no action,
	CONSTRAINT "reward_values" CHECK("rewards"."points">0 and "rewards"."discount_centavos">=0 and "rewards"."minimum_basket_centavos">="rewards"."discount_centavos" and "rewards"."cost_centavos">=0 and "rewards"."stock">=-1 and "rewards"."active" in (0,1))
);
