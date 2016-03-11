//--------------------------------------------------------------------------------------------------

protocol DirectionalItemCacheDataSource : class
{
    func itemKeyForIndex (itemIndex:Int) -> String?
    func itemValueForIndex (itemIndex:Int) -> AnyObject?
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

enum DirectionalItemCacheDirection
{
    case Forward
    case Backward
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

private class ItemRecord<T>
{
    let index:Int
    let key:String
    var value:T

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    init (index:Int, key:String, value:T)
    {
        self.index = index
        self.key = key
        self.value = value
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
}

//--------------------------------------------------------------------------------------------------


class DirectionalItemCache<T>
{
    private weak var dataSource:DirectionalItemCacheDataSource!
    private let maxItemRadius:Int
    private let bias:Int
    private let requestItemValuesAsync:Bool
    private var asyncQueue:dispatch_queue_t!
    private let capacity:Int
    private var currItemIndex:Int!
    private var items = [String: ItemRecord<T>]()
    private var cachingSessionID = 1

    //----------------------------------------------------------------------------------------------

    init (
        dataSource:DirectionalItemCacheDataSource, maxItemRadius:Int, bias:Int = 1,
        requestItemValuesAsync:Bool = false)
    {
        assert(maxItemRadius >= 0)
        assert(bias >= 1)

        self.dataSource = dataSource
        self.maxItemRadius = maxItemRadius
        self.bias = bias
        self.requestItemValuesAsync = requestItemValuesAsync
        self.capacity = 1 + 2*maxItemRadius

        if requestItemValuesAsync
        {
            self.asyncQueue =
                dispatch_queue_create("DirectionalItemCache.asyncQueue", DISPATCH_QUEUE_CONCURRENT)
        }
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    func changeCurrItemIndex (
        itemIndex:Int, withDirection direction:DirectionalItemCacheDirection? = nil)
    {
        let useDirection:DirectionalItemCacheDirection
        if self.currItemIndex == nil
        {
            useDirection = direction ?? .Forward
        }
        else
        {
            if direction == nil
            {
                useDirection = itemIndex >= self.currItemIndex ? .Forward : .Backward
            }
            else
            {
                useDirection = direction!
            }
        }

        self.currItemIndex = itemIndex

        let jCachingSessionID = self.cachingSessionID

        let addItemToCache = { [weak self] (i:Int, itemKey:String) in
            guard let sSelf = self else
            {
                return
            }
            guard let dataSource = sSelf.dataSource else
            {
                return
            }

            let itemValue:T! = dataSource.itemValueForIndex(i) as? T
            if itemValue == nil
            {
                return
            }

            let doAddingWithPurging = { [weak sSelf] in
                // Always run on the main queue.

                guard let sSelf = sSelf else
                {
                    return
                }

                if sSelf.requestItemValuesAsync
                {
                    if jCachingSessionID != sSelf.cachingSessionID
                    {
                        return
                    }
                    guard let dataSource = sSelf.dataSource else
                    {
                        return
                    }
                    if itemKey != dataSource.itemKeyForIndex(i)
                    {
                        return
                    }
                }

                if sSelf.items.count == sSelf.capacity
                {
                    // The cache is full.  Purge the item being most distant from the current index.
                    var sortedItems = Array(sSelf.items.values)
                    sortedItems.sortInPlace { item0, item1 in
                        let dist0 = abs(item0.index - sSelf.currItemIndex)
                        let dist1 = abs(item1.index - sSelf.currItemIndex)
                        return dist0 < dist1
                    }
                    let purgeItemKey = sortedItems.last!.key
                    sSelf.items.removeValueForKey(purgeItemKey)
                }

                let itemRecord = ItemRecord<T>(index: i, key: itemKey, value: itemValue)
                sSelf.items[itemKey] = itemRecord
            }

            if !sSelf.requestItemValuesAsync
            {
                doAddingWithPurging()
            }
            else
            {
                dispatch_async(dispatch_get_main_queue()) {
                    doAddingWithPurging()
                }
            }
        }

        let currItemKey = self.dataSource.itemKeyForIndex(self.currItemIndex)!
        if self.items[currItemKey] == nil
        {
            addItemToCache(self.currItemIndex, currItemKey)
        }

        var forwardIndexes = [Int]()
        var backwardIndexes = [Int]()
        var i:Int
        i = itemIndex + 1
        while forwardIndexes.count < self.maxItemRadius
        {
            forwardIndexes.append(i)
            i++
        }
        i = itemIndex - 1
        while backwardIndexes.count < self.maxItemRadius
        {
            backwardIndexes.append(i)
            i--
        }

        var primaryIndexes:[Int]
        var secondaryIndexes:[Int]
        if useDirection == .Forward
        {
            primaryIndexes = forwardIndexes
            secondaryIndexes = backwardIndexes
        }
        else  // .Backward
        {
            primaryIndexes = backwardIndexes
            secondaryIndexes = forwardIndexes
        }

        let maybeAddItemToCache = { (i:Int) in
            if i < 0
            {
                return
            }

            if let itemKey = self.dataSource.itemKeyForIndex(i)
            {
                if self.items[itemKey] == nil
                {
                    if !self.requestItemValuesAsync
                    {
                        addItemToCache(i, itemKey)
                    }
                    else
                    {
                        dispatch_async(self.asyncQueue) {
                            addItemToCache(i, itemKey)
                        }
                    }
                }
            }
        }

        var pBias = 0
        while !primaryIndexes.isEmpty
        {
            let i = primaryIndexes.removeFirst()
            maybeAddItemToCache(i)

            pBias++
            if pBias == self.bias
            {
                if !secondaryIndexes.isEmpty
                {
                    let i = secondaryIndexes.removeFirst()
                    maybeAddItemToCache(i)
                }
                pBias = 0
            }
        }
        while !secondaryIndexes.isEmpty
        {
            let i = secondaryIndexes.removeFirst()
            maybeAddItemToCache(i)
        }
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    subscript (key:String) -> T?
    {
        return self.items[key]?.value
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    func contains (key:String) -> Bool
    {
        return self.items[key] != nil
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    func itemForIndex (index:Int) -> T!
    {
        for itemRecord in self.items.values
        {
            if itemRecord.index == index
            {
                return itemRecord.value
            }
        }
        return nil
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    func updateItem (value:T, forKey key:String)
    {
        if let itemRecord = self.items[key]
        {
            itemRecord.value = value
        }
        else
        {
            assert(false)
        }
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    func walk (closure:((itemValue:T) -> Void))
    {
        for itemRecord in self.items.values
        {
            closure(itemValue: itemRecord.value)
        }
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    func itemsArray () -> [T]
    {
        return self.items.values.map { $0.value }
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    func clear ()
    {
        self.cachingSessionID = self.cachingSessionID &+ 1
        self.items = [String: ItemRecord<T>]()
        self.currItemIndex = nil
    }

    //----------------------------------------------------------------------------------------------
}



