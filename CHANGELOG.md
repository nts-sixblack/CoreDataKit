# Changelog

## 1.2.0 - 2026-04-24

- Added `BatchWriteOptions` for configurable batch size and writer-context reset behavior.
- Added `PersistentStore.batchUpdate(options:_:)` for memory-aware large write transactions.
- Added `NSManagedObjectContext.fetchObjectDictionary(_:keyedBy:values:batchSize:)` to fetch existing managed objects by key in batches.
- Updated `BaseRepository.store(_ items:)` to chunk large array writes, save after each chunk, and reset the context to reduce memory pressure.
- Added tests for 10,000-object batch insert and upsert flows.

## 1.1.0

- Added fetch-request monitoring with `DataChange` events.
- Updated repository APIs with `monitorAll()` and `monitorById(_:)`.

## 1.0.0

- Initial CoreDataKit release with protocol-based persistence, repository helpers, and Combine publishers.
