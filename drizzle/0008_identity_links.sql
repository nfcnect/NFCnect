CREATE TABLE `identity_links` (
	`supabase_user_id` text PRIMARY KEY NOT NULL,
	`actor_id` text NOT NULL,
	`verified_email` text NOT NULL,
	`verified_at` text DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now')) NOT NULL,
	`verification_reference` text NOT NULL,
	CONSTRAINT "identity_reference" CHECK(length("identity_links"."verification_reference") between 3 and 300),
	CONSTRAINT "legacy_actor" CHECK(length("identity_links"."actor_id")>0 and "identity_links"."actor_id" not like 'supabase:%')
);
--> statement-breakpoint
CREATE UNIQUE INDEX `identity_links_actor_id_unique` ON `identity_links` (`actor_id`);--> statement-breakpoint
CREATE TRIGGER identity_link_guard BEFORE INSERT ON identity_links BEGIN
 SELECT CASE WHEN NOT EXISTS(SELECT 1 FROM memberships WHERE user_id=NEW.actor_id) AND NOT EXISTS(SELECT 1 FROM employees WHERE user_id=NEW.actor_id) THEN RAISE(ABORT,'legacy_actor_unavailable') END;
 SELECT CASE WHEN EXISTS(SELECT 1 FROM memberships WHERE user_id='supabase:'||NEW.supabase_user_id) OR EXISTS(SELECT 1 FROM employees WHERE user_id='supabase:'||NEW.supabase_user_id) THEN RAISE(ABORT,'new_identity_already_in_use') END;
END;
