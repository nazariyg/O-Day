//--------------------------------------------------------------------------------------------------

private class ItemRecord<T>
{
    let key:String
    let value:T
    var ordinal:UInt64
    var added:NSDate
    var lastAccessed:NSDate

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    init (key:String, value:T, ordinal:UInt64, added:NSDate, lastAccessed:NSDate)
    {
        self.key = key
        self.value = value
        self.ordinal = ordinal
        self.added = added
        self.lastAccessed = lastAccessed
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
}

//--------------------------------------------------------------------------------------------------


class KeyedItemsCache<T>
{
    let capacity:Int

    private let purgeByAddedDateInsteadOfLastAccessedDate:Bool
    private var items = [String: ItemRecord<T>]()
    private var lastAddedItemOrdinal:UInt64!

    //----------------------------------------------------------------------------------------------

    init (capacity:Int, purgeByAddedDateInsteadOfLastAccessedDate:Bool = false)
    {
        assert(capacity >= 1)

        self.capacity = capacity
        self.purgeByAddedDateInsteadOfLastAccessedDate = purgeByAddedDateInsteadOfLastAccessedDate
    }

    //----------------------------------------------------------------------------------------------

    func addItem (item:T, forKey key:String, usingAddedDate useAddedDate:NSDate? = nil)
    {
        assert(self.items[key] == nil)

        if self.items.count == self.capacity
        {
            let itemsArray = self.sortedItemRecords()
            let outItem = itemsArray.first!
            self.items.removeValueForKey(outItem.key)
        }

        let ordinal = self.lastAddedItemOrdinal == nil ? 1 : self.lastAddedItemOrdinal + 1
        let added = useAddedDate ?? NSDate()
        let addItem =
            ItemRecord<T>(
                key: key, value: item, ordinal: ordinal, added: added, lastAccessed: added)
        self.items[key] = addItem

        self.lastAddedItemOrdinal = ordinal
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    subscript (key:String) -> T?
    {
        if let item = self.items[key]
        {
            item.lastAccessed = NSDate()
            return item.value
        }
        else
        {
            return nil
        }
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    func contains (key:String) -> Bool
    {
        return self.items[key] != nil
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    func reversePurgeSorting ()
    {
        let itemsArray = self.sortedItemRecords()
        let reverseItemsArray = Array(itemsArray.reverse())

        self.items = [String: ItemRecord<T>]()
        for (i, item) in itemsArray.enumerate()
        {
            let revItem = reverseItemsArray[i]

            let addItem:ItemRecord<T>
            if !self.purgeByAddedDateInsteadOfLastAccessedDate
            {
                addItem =
                    ItemRecord<T>(
                        key: item.key, value: item.value, ordinal: item.ordinal,
                        added: item.added, lastAccessed: revItem.lastAccessed)
            }
            else
            {
                addItem =
                    ItemRecord<T>(
                        key: item.key, value: item.value, ordinal: revItem.ordinal,
                        added: revItem.added, lastAccessed: item.lastAccessed)
            }
            self.items[item.key] = addItem
        }
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    func sortedItems () -> [T]
    {
        return self.sortedItemRecords().map { $0.value }
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    func clear ()
    {
        self.items.removeAll()
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    private func sortedItemRecords () -> [ItemRecord<T>]
    {
        var itemsArray = Array(self.items.values)
        if !self.purgeByAddedDateInsteadOfLastAccessedDate
        {
            itemsArray.sortInPlace { item0, item1 in
                let lastAccessedComparison = item0.lastAccessed.compare(item1.lastAccessed)
                if lastAccessedComparison != .OrderedSame
                {
                    return lastAccessedComparison == .OrderedAscending
                }
                else
                {
                    return item0.ordinal < item1.ordinal
                }
            }
        }
        else
        {
            itemsArray.sortInPlace { item0, item1 in
                let addedComparison = item0.added.compare(item1.added)
                if addedComparison != .OrderedSame
                {
                    return addedComparison == .OrderedAscending
                }
                else
                {
                    return item0.ordinal < item1.ordinal
                }
            }
        }
        return itemsArray
    }

    //----------------------------------------------------------------------------------------------
}



