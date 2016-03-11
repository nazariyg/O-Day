//--------------------------------------------------------------------------------------------------

protocol FPType : Comparable
{
    init(_ value:Double)
}

extension Double : FPType { }
extension CGFloat : FPType { }
extension Float : FPType { }

//--------------------------------------------------------------------------------------------------

func sign<T:FPType> (value:T) -> T
{
    if value < T(0.0)
    {
        return T(-1.0)
    }
    if value > T(0.0)
    {
        return T(1.0)
    }
    return T(0.0)
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

func clamp<T:FPType> (value:T, _ minValue:T, _ maxValue:T) -> T
{
    if value < minValue
    {
        return minValue
    }
    if value > maxValue
    {
        return maxValue
    }
    return value
}

//--------------------------------------------------------------------------------------------------



