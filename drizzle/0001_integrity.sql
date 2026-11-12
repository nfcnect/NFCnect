CREATE UNIQUE INDEX one_active_card ON cards(membership_id) WHERE status='active';
--> statement-breakpoint
CREATE TRIGGER card_scope BEFORE INSERT ON cards BEGIN
 SELECT CASE WHEN NOT EXISTS(SELECT 1 FROM memberships WHERE id=NEW.membership_id AND business_id=NEW.business_id) THEN RAISE(ABORT,'invalid_scope') END;
END;
--> statement-breakpoint
CREATE TRIGGER purchase_guard BEFORE INSERT ON purchases BEGIN
 SELECT CASE WHEN NOT EXISTS(SELECT 1 FROM employees WHERE business_id=NEW.business_id AND user_id=NEW.actor_id AND status='active') THEN RAISE(ABORT,'forbidden') END;
 SELECT CASE WHEN NOT EXISTS(SELECT 1 FROM memberships WHERE id=NEW.membership_id AND business_id=NEW.business_id AND status='active') THEN RAISE(ABORT,'membership_unavailable') END;
 SELECT CASE WHEN NOT EXISTS(SELECT 1 FROM businesses WHERE id=NEW.business_id AND step_centavos=NEW.step_centavos AND rule_version=NEW.rule_version) OR NEW.points<>NEW.amount_centavos/NEW.step_centavos THEN RAISE(ABORT,'rule_changed') END;
END;
--> statement-breakpoint
CREATE TRIGGER purchase_post AFTER INSERT ON purchases BEGIN
 INSERT INTO ledger(id,business_id,membership_id,delta,kind,source_id) VALUES('purchase:'||NEW.id,NEW.business_id,NEW.membership_id,NEW.points,'purchase',NEW.id);
 INSERT INTO audit(id,business_id,actor_id,event,target_id,detail) VALUES('purchase:'||NEW.id,NEW.business_id,NEW.actor_id,'purchase',NEW.id,NEW.receipt);
END;
--> statement-breakpoint
CREATE TRIGGER request_guard BEFORE INSERT ON reward_requests BEGIN
 SELECT CASE WHEN NOT EXISTS(SELECT 1 FROM memberships WHERE id=NEW.membership_id AND business_id=NEW.business_id AND user_id=NEW.requester_id AND status='active') THEN RAISE(ABORT,'forbidden') END;
 SELECT CASE WHEN NOT EXISTS(SELECT 1 FROM rewards WHERE id=NEW.reward_id AND business_id=NEW.business_id AND active=1 AND stock<>0 AND points=NEW.points) THEN RAISE(ABORT,'reward_unavailable') END;
 SELECT CASE WHEN (SELECT COALESCE(SUM(delta),0) FROM ledger WHERE business_id=NEW.business_id AND membership_id=NEW.membership_id)<NEW.points THEN RAISE(ABORT,'insufficient_points') END;
END;
--> statement-breakpoint
CREATE TRIGGER redemption_guard BEFORE INSERT ON redemptions BEGIN
 SELECT CASE WHEN NOT EXISTS(SELECT 1 FROM employees WHERE business_id=NEW.business_id AND user_id=NEW.actor_id AND status='active') THEN RAISE(ABORT,'forbidden') END;
 SELECT CASE WHEN NOT EXISTS(SELECT 1 FROM memberships WHERE id=NEW.membership_id AND business_id=NEW.business_id AND status='active') THEN RAISE(ABORT,'membership_unavailable') END;
 SELECT CASE WHEN NOT EXISTS(SELECT 1 FROM reward_requests q JOIN memberships m ON m.id=q.membership_id WHERE q.id=NEW.request_id AND q.business_id=NEW.business_id AND q.membership_id=NEW.membership_id AND q.reward_id=NEW.reward_id AND q.points=NEW.points AND q.requester_id=m.user_id AND q.expires_at>strftime('%Y-%m-%dT%H:%M:%fZ','now')) THEN RAISE(ABORT,'request_unavailable') END;
 SELECT CASE WHEN NOT EXISTS(SELECT 1 FROM rewards WHERE id=NEW.reward_id AND business_id=NEW.business_id AND active=1 AND stock<>0 AND points=NEW.points AND cost_centavos=NEW.cost_centavos AND minimum_basket_centavos<=NEW.basket_centavos) THEN RAISE(ABORT,'reward_unavailable') END;
 SELECT CASE WHEN (SELECT COALESCE(SUM(delta),0) FROM ledger WHERE business_id=NEW.business_id AND membership_id=NEW.membership_id)<NEW.points THEN RAISE(ABORT,'insufficient_points') END;
END;
--> statement-breakpoint
CREATE TRIGGER redemption_post AFTER INSERT ON redemptions BEGIN
 INSERT INTO ledger(id,business_id,membership_id,delta,kind,source_id) VALUES('redemption:'||NEW.id,NEW.business_id,NEW.membership_id,-NEW.points,'redemption',NEW.id);
 UPDATE rewards SET stock=stock-1 WHERE id=NEW.reward_id AND stock>0;
 INSERT INTO audit(id,business_id,actor_id,event,target_id,detail) VALUES('redemption:'||NEW.id,NEW.business_id,NEW.actor_id,'redemption',NEW.id,NEW.request_id);
END;
--> statement-breakpoint
CREATE TRIGGER refund_guard BEFORE INSERT ON refunds BEGIN
 SELECT CASE WHEN NOT EXISTS(SELECT 1 FROM employees WHERE business_id=NEW.business_id AND user_id=NEW.actor_id AND role='admin' AND status='active') THEN RAISE(ABORT,'forbidden') END;
 SELECT CASE WHEN NOT EXISTS(SELECT 1 FROM purchases WHERE id=NEW.purchase_id AND business_id=NEW.business_id) THEN RAISE(ABORT,'invalid_scope') END;
 SELECT CASE WHEN NEW.amount_centavos+(SELECT COALESCE(SUM(amount_centavos),0) FROM refunds WHERE purchase_id=NEW.purchase_id)>(SELECT amount_centavos FROM purchases WHERE id=NEW.purchase_id) THEN RAISE(ABORT,'refund_exceeds_purchase') END;
END;
--> statement-breakpoint
CREATE TRIGGER refund_post AFTER INSERT ON refunds BEGIN
 INSERT INTO ledger(id,business_id,membership_id,delta,kind,source_id)
 SELECT 'refund:'||NEW.id,p.business_id,p.membership_id,
 (p.amount_centavos-(SELECT SUM(amount_centavos) FROM refunds WHERE purchase_id=p.id))/p.step_centavos -
 (p.amount_centavos-(SELECT SUM(amount_centavos) FROM refunds WHERE purchase_id=p.id)+NEW.amount_centavos)/p.step_centavos,
 'refund',NEW.id FROM purchases p WHERE p.id=NEW.purchase_id;
 INSERT INTO audit(id,business_id,actor_id,event,target_id,detail) VALUES('refund:'||NEW.id,NEW.business_id,NEW.actor_id,'refund',NEW.id,NEW.reason);
END;
--> statement-breakpoint
CREATE TRIGGER fulfillment_guard BEFORE INSERT ON fulfillments BEGIN
 SELECT CASE WHEN NOT EXISTS(SELECT 1 FROM employees WHERE business_id=NEW.business_id AND user_id=NEW.actor_id AND status='active') THEN RAISE(ABORT,'forbidden') END;
 SELECT CASE WHEN NOT EXISTS(SELECT 1 FROM redemptions WHERE id=NEW.redemption_id AND business_id=NEW.business_id) OR EXISTS(SELECT 1 FROM cancellations WHERE redemption_id=NEW.redemption_id) THEN RAISE(ABORT,'redemption_unavailable') END;
END;
--> statement-breakpoint
CREATE TRIGGER fulfillment_post AFTER INSERT ON fulfillments BEGIN
 INSERT INTO audit(id,business_id,actor_id,event,target_id) VALUES('fulfillment:'||NEW.id,NEW.business_id,NEW.actor_id,'fulfilled',NEW.redemption_id);
END;
--> statement-breakpoint
CREATE TRIGGER cancellation_guard BEFORE INSERT ON cancellations BEGIN
 SELECT CASE WHEN NOT EXISTS(SELECT 1 FROM employees WHERE business_id=NEW.business_id AND user_id=NEW.actor_id AND role='admin' AND status='active') THEN RAISE(ABORT,'forbidden') END;
 SELECT CASE WHEN NOT EXISTS(SELECT 1 FROM redemptions WHERE id=NEW.redemption_id AND business_id=NEW.business_id) THEN RAISE(ABORT,'invalid_scope') END;
END;
--> statement-breakpoint
CREATE TRIGGER cancellation_post AFTER INSERT ON cancellations BEGIN
 INSERT INTO ledger(id,business_id,membership_id,delta,kind,source_id) SELECT 'cancel:'||NEW.id,business_id,membership_id,points,'cancellation',NEW.id FROM redemptions WHERE id=NEW.redemption_id;
 UPDATE rewards SET stock=stock+1 WHERE stock>=0 AND id=(SELECT reward_id FROM redemptions WHERE id=NEW.redemption_id);
 INSERT INTO audit(id,business_id,actor_id,event,target_id,detail) VALUES('cancel:'||NEW.id,NEW.business_id,NEW.actor_id,'redemption_canceled',NEW.redemption_id,NEW.reason);
END;
--> statement-breakpoint
CREATE TRIGGER invitation_claim_guard BEFORE UPDATE OF used_at ON invitations WHEN OLD.used_at IS NULL AND NEW.used_at IS NOT NULL BEGIN
 SELECT CASE WHEN NEW.claimed_user_id IS NULL OR NEW.expires_at<=strftime('%Y-%m-%dT%H:%M:%fZ','now') THEN RAISE(ABORT,'invitation_unavailable') END;
 SELECT CASE WHEN NEW.kind='customer' AND NOT EXISTS(SELECT 1 FROM memberships WHERE id=NEW.membership_id AND business_id=NEW.business_id AND user_id IS NULL AND status='active') THEN RAISE(ABORT,'invitation_unavailable') END;
 SELECT CASE WHEN NEW.kind='employee' AND NEW.role NOT IN ('admin','cashier') THEN RAISE(ABORT,'forbidden') END;
END;
--> statement-breakpoint
CREATE TRIGGER invitation_claim_post AFTER UPDATE OF used_at ON invitations WHEN OLD.used_at IS NULL AND NEW.used_at IS NOT NULL BEGIN
 UPDATE memberships SET user_id=NEW.claimed_user_id WHERE id=NEW.membership_id AND NEW.kind='customer';
 INSERT INTO employees(id,business_id,user_id,email,role) SELECT NEW.id,NEW.business_id,NEW.claimed_user_id,NEW.email,NEW.role WHERE NEW.kind='employee';
 INSERT INTO audit(id,business_id,actor_id,event,target_id) VALUES('claim:'||NEW.id,NEW.business_id,NEW.claimed_user_id,'invitation_claimed',NEW.id);
END;
--> statement-breakpoint
CREATE TRIGGER ledger_no_update BEFORE UPDATE ON ledger BEGIN SELECT RAISE(ABORT,'immutable_ledger'); END;
--> statement-breakpoint
CREATE TRIGGER ledger_no_delete BEFORE DELETE ON ledger BEGIN SELECT RAISE(ABORT,'immutable_ledger'); END;
--> statement-breakpoint
CREATE TRIGGER audit_no_update BEFORE UPDATE ON audit BEGIN SELECT RAISE(ABORT,'immutable_audit'); END;
--> statement-breakpoint
CREATE TRIGGER audit_no_delete BEFORE DELETE ON audit BEGIN SELECT RAISE(ABORT,'immutable_audit'); END;

--> statement-breakpoint
CREATE TRIGGER purchases_no_update BEFORE UPDATE ON purchases BEGIN SELECT RAISE(ABORT,'immutable_record'); END;

--> statement-breakpoint
CREATE TRIGGER purchases_no_delete BEFORE DELETE ON purchases BEGIN SELECT RAISE(ABORT,'immutable_record'); END;

--> statement-breakpoint
CREATE TRIGGER refunds_no_update BEFORE UPDATE ON refunds BEGIN SELECT RAISE(ABORT,'immutable_record'); END;

--> statement-breakpoint
CREATE TRIGGER refunds_no_delete BEFORE DELETE ON refunds BEGIN SELECT RAISE(ABORT,'immutable_record'); END;

--> statement-breakpoint
CREATE TRIGGER redemptions_no_update BEFORE UPDATE ON redemptions BEGIN SELECT RAISE(ABORT,'immutable_record'); END;

--> statement-breakpoint
CREATE TRIGGER redemptions_no_delete BEFORE DELETE ON redemptions BEGIN SELECT RAISE(ABORT,'immutable_record'); END;

--> statement-breakpoint
CREATE TRIGGER reward_requests_no_update BEFORE UPDATE ON reward_requests BEGIN SELECT RAISE(ABORT,'immutable_record'); END;

--> statement-breakpoint
CREATE TRIGGER reward_requests_no_delete BEFORE DELETE ON reward_requests BEGIN SELECT RAISE(ABORT,'immutable_record'); END;

--> statement-breakpoint
CREATE TRIGGER fulfillments_no_update BEFORE UPDATE ON fulfillments BEGIN SELECT RAISE(ABORT,'immutable_record'); END;

--> statement-breakpoint
CREATE TRIGGER fulfillments_no_delete BEFORE DELETE ON fulfillments BEGIN SELECT RAISE(ABORT,'immutable_record'); END;

--> statement-breakpoint
CREATE TRIGGER cancellations_no_update BEFORE UPDATE ON cancellations BEGIN SELECT RAISE(ABORT,'immutable_record'); END;

--> statement-breakpoint
CREATE TRIGGER cancellations_no_delete BEFORE DELETE ON cancellations BEGIN SELECT RAISE(ABORT,'immutable_record'); END;

--> statement-breakpoint
CREATE TRIGGER request_audit AFTER INSERT ON reward_requests BEGIN
 INSERT INTO audit(id,business_id,actor_id,event,target_id) VALUES('request:'||NEW.id,NEW.business_id,NEW.requester_id,'reward_requested',NEW.id);
END;
