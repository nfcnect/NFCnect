CREATE TRIGGER business_validity_insert BEFORE INSERT ON businesses WHEN NEW.validity_days IS NOT NULL AND (typeof(NEW.validity_days)<>'integer' OR NEW.validity_days<1 OR NEW.validity_days>3650) BEGIN SELECT RAISE(ABORT,'invalid_validity'); END;
--> statement-breakpoint
CREATE TRIGGER business_validity_update BEFORE UPDATE OF validity_days ON businesses WHEN NEW.validity_days IS NOT NULL AND (typeof(NEW.validity_days)<>'integer' OR NEW.validity_days<1 OR NEW.validity_days>3650) BEGIN SELECT RAISE(ABORT,'invalid_validity'); END;
--> statement-breakpoint
CREATE TRIGGER purchase_validity_guard BEFORE INSERT ON purchases WHEN NOT EXISTS(SELECT 1 FROM businesses b WHERE b.id=NEW.business_id AND b.validity_days IS NEW.validity_days) BEGIN SELECT RAISE(ABORT,'rule_changed'); END;
--> statement-breakpoint
CREATE TRIGGER cancellation_validity_guard BEFORE INSERT ON cancellations WHEN NOT EXISTS(SELECT 1 FROM businesses b WHERE b.id=NEW.business_id AND b.validity_days IS NEW.validity_days) BEGIN SELECT RAISE(ABORT,'rule_changed'); END;
--> statement-breakpoint
CREATE TRIGGER point_check_guard BEFORE INSERT ON point_checks BEGIN
 SELECT CASE WHEN NOT EXISTS(SELECT 1 FROM memberships WHERE id=NEW.membership_id AND business_id=NEW.business_id) THEN RAISE(ABORT,'invalid_scope') END;
 SELECT CASE WHEN NEW.expected_version<>(SELECT COALESCE(MAX(rowid),0) FROM ledger WHERE membership_id=NEW.membership_id AND business_id=NEW.business_id) THEN RAISE(ABORT,'points_changed') END;
 SELECT CASE WHEN NEW.expired_points<0 OR NEW.expired_points<>(SELECT COALESCE(SUM(json_extract(value,'$.points')),0) FROM json_each(NEW.details)) THEN RAISE(ABORT,'invalid_expiration') END;
END;
--> statement-breakpoint
CREATE TRIGGER point_check_post AFTER INSERT ON point_checks WHEN NEW.expired_points>0 BEGIN
 INSERT INTO ledger(id,business_id,membership_id,delta,kind,source_id) VALUES('expiration:'||NEW.id,NEW.business_id,NEW.membership_id,-NEW.expired_points,'expiration',NEW.id);
 INSERT INTO audit(id,business_id,actor_id,event,target_id,detail) VALUES('expiration:'||NEW.id,NEW.business_id,'system','points_expired',NEW.membership_id,CAST(NEW.expired_points AS TEXT));
END;
--> statement-breakpoint
CREATE TRIGGER point_checks_no_update BEFORE UPDATE ON point_checks BEGIN SELECT RAISE(ABORT,'immutable_record'); END;
--> statement-breakpoint
CREATE TRIGGER point_checks_no_delete BEFORE DELETE ON point_checks BEGIN SELECT RAISE(ABORT,'immutable_record'); END;

--> statement-breakpoint
DROP TRIGGER cancellations_no_update;
--> statement-breakpoint
CREATE TRIGGER cancellations_no_update BEFORE UPDATE ON cancellations WHEN NOT (NEW.id IS OLD.id AND NEW.business_id IS OLD.business_id AND NEW.redemption_id IS OLD.redemption_id AND NEW.actor_id IS OLD.actor_id AND NEW.created_at IS OLD.created_at AND NEW.validity_days IS OLD.validity_days AND NEW.reason='[Removed on profile anonymization]' AND EXISTS(SELECT 1 FROM privacy_redactions p JOIN redemptions d ON d.membership_id=p.membership_id WHERE d.id=OLD.redemption_id AND p.business_id=OLD.business_id)) BEGIN SELECT RAISE(ABORT,'immutable_record'); END;
