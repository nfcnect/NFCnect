CREATE TRIGGER hybrid_purchase_guard BEFORE INSERT ON purchases BEGIN
 SELECT CASE WHEN NEW.entry_method NOT IN ('nfc','card_link','receipt') THEN RAISE(ABORT,'invalid_entry_method') END;
 SELECT CASE WHEN NEW.entry_method<>'receipt' AND NEW.backup_reason IS NOT NULL THEN RAISE(ABORT,'invalid_backup_reason') END;
 SELECT CASE WHEN NEW.entry_method='receipt' AND NEW.backup_reason IS NOT NULL AND NEW.backup_reason NOT IN ('forgot_card','reader_unavailable','card_unreadable','receipt_claim','legacy_manual_entry') THEN RAISE(ABORT,'invalid_backup_reason') END;
END;
--> statement-breakpoint
CREATE TRIGGER hybrid_purchase_audit AFTER INSERT ON purchases BEGIN
 INSERT INTO audit(id,business_id,actor_id,event,target_id,detail) VALUES('entry:'||NEW.id,NEW.business_id,NEW.actor_id,'purchase_entry_method',NEW.id,NEW.entry_method||COALESCE(' / '||NEW.backup_reason,''));
END;
