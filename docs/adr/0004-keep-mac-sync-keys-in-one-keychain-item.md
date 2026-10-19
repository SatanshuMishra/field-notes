# Keep the Mac sync keys in one keychain item

The Mac app is signed ad hoc with no developer team, so it can only use the legacy login keychain, which trusts an app by the hash of its exact binary and asks for access once per item on every new release. To ask once per release instead of once per key, the Mac keeps all its sync keys in one keychain item, `field_notes.sync.bundle`, a JSON object of the values, and the first run of a release that finds the earlier one-item-per-key layout moves those items into it before deleting them. Developer ID signing with the Data Protection keychain would end the prompts entirely but needs a paid Apple developer account; keeping the keys in a file in the app's sandbox would end them too but drops the keychain's encryption at rest. Android, Windows and Linux keep one item per key, since none of them prompts.

Status: accepted.

Consequences: the one item is never deleted, even after a wipe, so an earlier item that survived the move can never be moved back in. Moving to Developer ID signing later would supersede this and allow the Data Protection keychain.
