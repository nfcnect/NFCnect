CREATE TRIGGER privacy_authorize BEFORE INSERT ON privacy_redactions BEGIN
 SELECT CASE WHEN NOT EXISTS(SELECT 1 FROM employees WHERE business_id=NEW.business_id AND user_id=NEW.actor_id AND role='admin' AND status='active') THEN RAISE(ABORT,'forbidden') END;
 SELECT CASE WHEN NOT EXISTS(SELECT 1 FROM memberships WHERE id=NEW.membership_id AND business_id=NEW.business_id AND anonymized_at IS NULL) THEN RAISE(ABORT,'membership_unavailable') END;
END;
--> statement-breakpoint
DROP TRIGGER audit_no_update;
--> statement-breakpoint
DROP TRIGGER refunds_no_update;
--> statement-breakpoint
DROP TRIGGER cancellations_no_update;
--> statement-breakpoint
DROP TRIGGER reward_requests_no_update;
--> statement-breakpoint
CREATE TRIGGER audit_no_update BEFORE UPDATE ON audit WHEN NOT (NEW.id IS OLD.id AND NEW.business_id IS OLD.business_id AND NEW.event IS OLD.event AND NEW.target_id IS OLD.target_id AND NEW.created_at IS OLD.created_at AND (
 (NEW.detail IS OLD.detail AND EXISTS(
 SELECT 1 FROM privacy_redactions p JOIN memberships m ON m.id=p.membership_id WHERE p.business_id=OLD.business_id AND NEW.actor_id='redacted:'||p.membership_id AND OLD.actor_id=m.user_id AND
 ((OLD.event='reward_requested' AND EXISTS(SELECT 1 FROM reward_requests q WHERE q.id=OLD.target_id AND q.membership_id=p.membership_id)) OR
 (OLD.event='invitation_claimed' AND EXISTS(SELECT 1 FROM invitations i WHERE i.id=OLD.target_id AND i.membership_id=p.membership_id)))))
 OR (NEW.actor_id IS OLD.actor_id AND NEW.detail='[Removed on profile anonymization]' AND EXISTS(
 SELECT 1 FROM privacy_redactions p WHERE p.business_id=OLD.business_id AND (
 (OLD.event IN ('membership_status','card_replaced') AND OLD.target_id=p.membership_id) OR
 (OLD.event='refund' AND EXISTS(SELECT 1 FROM refunds f JOIN purchases x ON x.id=f.purchase_id WHERE f.id=OLD.target_id AND x.membership_id=p.membership_id)) OR
 (OLD.event='redemption_canceled' AND EXISTS(SELECT 1 FROM redemptions d WHERE d.id=OLD.target_id AND d.membership_id=p.membership_id)))))
 )) BEGIN SELECT RAISE(ABORT,'immutable_audit'); END;
--> statement-breakpoint
CREATE TRIGGER reward_requests_no_update BEFORE UPDATE ON reward_requests WHEN NOT (NEW.id IS OLD.id AND NEW.business_id IS OLD.business_id AND NEW.membership_id IS OLD.membership_id AND NEW.reward_id IS OLD.reward_id AND NEW.points IS OLD.points AND NEW.idempotency_key IS OLD.idempotency_key AND NEW.payload_hash IS OLD.payload_hash AND NEW.expires_at IS OLD.expires_at AND NEW.created_at IS OLD.created_at AND NEW.requester_id='redacted:'||OLD.membership_id AND EXISTS(SELECT 1 FROM privacy_redactions p WHERE p.membership_id=OLD.membership_id AND p.business_id=OLD.business_id)) BEGIN SELECT RAISE(ABORT,'immutable_record'); END;
--> statement-breakpoint
CREATE TRIGGER refunds_no_update BEFORE UPDATE ON refunds WHEN NOT (NEW.id IS OLD.id AND NEW.business_id IS OLD.business_id AND NEW.purchase_id IS OLD.purchase_id AND NEW.amount_centavos IS OLD.amount_centavos AND NEW.actor_id IS OLD.actor_id AND NEW.idempotency_key IS OLD.idempotency_key AND NEW.payload_hash IS OLD.payload_hash AND NEW.created_at IS OLD.created_at AND NEW.reason='[Removed on profile anonymization]' AND EXISTS(SELECT 1 FROM privacy_redactions p JOIN purchases x ON x.membership_id=p.membership_id WHERE x.id=OLD.purchase_id AND p.business_id=OLD.business_id)) BEGIN SELECT RAISE(ABORT,'immutable_record'); END;
--> statement-breakpoint
CREATE TRIGGER cancellations_no_update BEFORE UPDATE ON cancellations WHEN NOT (NEW.id IS OLD.id AND NEW.business_id IS OLD.business_id AND NEW.redemption_id IS OLD.redemption_id AND NEW.actor_id IS OLD.actor_id AND NEW.created_at IS OLD.created_at AND NEW.reason='[Removed on profile anonymization]' AND EXISTS(SELECT 1 FROM privacy_redactions p JOIN redemptions d ON d.membership_id=p.membership_id WHERE d.id=OLD.redemption_id AND p.business_id=OLD.business_id)) BEGIN SELECT RAISE(ABORT,'immutable_record'); END;
--> statement-breakpoint
CREATE TRIGGER privacy_apply AFTER INSERT ON privacy_redactions BEGIN
 UPDATE audit SET actor_id='redacted:'||NEW.membership_id WHERE business_id=NEW.business_id AND actor_id=(SELECT user_id FROM memberships WHERE id=NEW.membership_id) AND
 ((event='reward_requested' AND target_id IN (SELECT id FROM reward_requests WHERE membership_id=NEW.membership_id)) OR (event='invitation_claimed' AND target_id IN (SELECT id FROM invitations WHERE membership_id=NEW.membership_id)));
 UPDATE audit SET detail='[Removed on profile anonymization]' WHERE business_id=NEW.business_id AND (
 (event IN ('membership_status','card_replaced') AND target_id=NEW.membership_id) OR
 (event='refund' AND target_id IN (SELECT f.id FROM refunds f JOIN purchases x ON x.id=f.purchase_id WHERE x.membership_id=NEW.membership_id)) OR
 (event='redemption_canceled' AND target_id IN (SELECT id FROM redemptions WHERE membership_id=NEW.membership_id)));
 UPDATE reward_requests SET requester_id='redacted:'||NEW.membership_id WHERE membership_id=NEW.membership_id AND business_id=NEW.business_id;
 UPDATE refunds SET reason='[Removed on profile anonymization]' WHERE business_id=NEW.business_id AND purchase_id IN (SELECT id FROM purchases WHERE membership_id=NEW.membership_id);
 UPDATE cancellations SET reason='[Removed on profile anonymization]' WHERE business_id=NEW.business_id AND redemption_id IN (SELECT id FROM redemptions WHERE membership_id=NEW.membership_id);
 DELETE FROM invitations WHERE membership_id=NEW.membership_id AND business_id=NEW.business_id;
 DELETE FROM cards WHERE membership_id=NEW.membership_id AND business_id=NEW.business_id;
 UPDATE memberships SET display_name='Anonymized member',user_id=NULL,status='closed',anonymized_at=NEW.created_at WHERE id=NEW.membership_id AND business_id=NEW.business_id;
 INSERT INTO audit(id,business_id,actor_id,event,target_id) VALUES('privacy:'||NEW.id,NEW.business_id,NEW.actor_id,'membership_anonymized',NEW.membership_id);
END;
--> statement-breakpoint
CREATE TRIGGER anonymized_profile_locked BEFORE UPDATE ON memberships WHEN OLD.anonymized_at IS NOT NULL BEGIN SELECT RAISE(ABORT,'profile_anonymized'); END;
--> statement-breakpoint
CREATE TRIGGER anonymized_card_blocked BEFORE INSERT ON cards WHEN EXISTS(SELECT 1 FROM memberships WHERE id=NEW.membership_id AND anonymized_at IS NOT NULL) BEGIN SELECT RAISE(ABORT,'profile_anonymized'); END;
--> statement-breakpoint
CREATE TRIGGER anonymized_invite_blocked BEFORE INSERT ON invitations WHEN EXISTS(SELECT 1 FROM memberships WHERE id=NEW.membership_id AND anonymized_at IS NOT NULL) BEGIN SELECT RAISE(ABORT,'profile_anonymized'); END;
--> statement-breakpoint
CREATE TRIGGER privacy_no_update BEFORE UPDATE ON privacy_redactions BEGIN SELECT RAISE(ABORT,'immutable_record'); END;
--> statement-breakpoint
CREATE TRIGGER privacy_no_delete BEFORE DELETE ON privacy_redactions BEGIN SELECT RAISE(ABORT,'immutable_record'); END;
