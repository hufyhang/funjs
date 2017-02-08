do (window) ->
  isArray = (o) -> return Object::toString.call(o) is '[object Array]'

  fns = {
    isArray: isArray
    isObject: (o) ->
      return typeof o is 'object' and not isArray(o)
    isNumber: (o) ->
      return typeof o is 'number' and not isNaN(o)
    isFunction: (o) ->
      return typeof o is 'function'
    isString: (o) ->
      return typeof o is 'string'
    isBoolean: (o) ->
      return typeof o is 'boolean'
    isNull: (o) ->
      return o is null
    isUndefined: (o) ->
      return o is undefined
    isNone: (o) ->
      # 用于Django
      return typeof o is 'string' and o.trim() is 'None'
    isNaN: (o) ->
      return typeof o is 'number' and isNaN(o)
    isEmpty: (o) ->
      if fns.isString o
        return o is ''
      else if fns.isArray o
        return o.length is 0
      else if fns.isObject o
        return JSON.stringify(o) is '{}'
      else
        throw new TypeError "The type of #{o} (#{typeof o}) can only be either string, or array, or object."


    # compose :: [fns] -> fn
    # 用于将函数进行串联复合。复合后的新函数的执行顺序从左至右依次执行。
    compose: (callbacks) ->
      callbacks = if isArray(callbacks) then callbacks else [].concat callbacks

      return (argv) ->
        result = undefined
        param = argv

        process = (buffer, fn) -> return fn(buffer)

        result = fns.reduce callbacks, process, param
        return result

    # throwError :: ErrorType -> (string) -> Throw exception
    # 用于创建 `type` 类型的exception thrower函数。
    throwError: (errorType) ->
      throw new TypeError("#{errorType} is not a valid error type." ) if typeof errorType isnt 'function'

      return (msg) ->
        throw new errorType(msg)

    # existy :: [any : optional] -> (any) -> boolean
    # 用于创建检查某变量是否为空(默认 null 和 undefined)的函数。
    # `emptyValues` 为除null和undefined以外的空值列表。
    # 对于 Django 的 None返回值比较有用。
    # 比如,使用时只需:
    # isEmpty = existy ['None']
    # isEmpty some_django_field
    existy: (emptyValues = []) ->
      emptyValues = [emptyValues] if not isArray emptyValues

      return (o) ->
        amongList = ->
          for empty in emptyValues
            return true if empty is o
          return false

        return o? and not amongList()

    # either :: any, [function] -> boolean
    # 用于判断某个变量是否满足任意一个条件。
    either: (obj, fns) ->
      fns = [fns] if not isArray fns
      result = false
      index = -1
      while ++index < fns.length
        fn = fns[index]
        result = true if typeof fn is 'function' and fn.call(obj, obj) is true

      return result

    # fulfill :: any, [function] -> boolean
    # 用于判断某个变量是否满足全部条件。
    fulfill: (obj, checkList) ->
      checkList = [checkList] if not isArray checkList
      check = (result, fn) ->
        res = if typeof fn is 'function' and fn.call(obj, obj) then true else false
        return result and res
      return fns.reduce(checkList, check, true)


    # iterateObject :: object, function, any:optional -> any
    # 用于遍历对象
    iterateObject: (obj, fn, initial = undefined) ->
      throw new TypeError "#{obj} (#{typeof obj}) is not an object." if typeof obj isnt 'object'
      result = initial
      for own key, value of obj
        result = fn result, key, value, obj
      return result

    reduceObject: @iterateObject

    forIn: (obj, fn) ->
      throw new TypeError "#{obj} (#{typeof obj}) is not an object." if typeof obj isnt 'object'
      throw new TypeError "#{fn} (#{typeof fn}) is not a function."  if not fns.isFunction fn
      for own key, value of obj
        fn(key, value, obj)
      return obj


    # reduce :: [any], function, any:optional -> any
    # 数组的reduce函数
    reduce: (arr, fn, initial) ->
      throw new TypeError "#{arr} (#{typeof arr}) is not an array." if not isArray arr
      throw new TypeError "#{fn} (#{typeof fn}) is not a function." if typeof fn isnt 'function'
      return [] if arr.length is 0

      accumulator = initial
      index = -1

      if arguments.length < 3
        index = 0
        accumulator = arr[0]

      while ++index < arr.length
        accumulator = fn accumulator, arr[index], index, arr
      return accumulator

    # reduceRight :: [any], function, any:optional -> any
    # 数组的reduceRight函数
    reduceRight: (arr, fn, initial) ->
      throw new TypeError "#{arr} (#{typeof arr}) is not an array." if not isArray arr
      throw new TypeError "#{fn} (#{typeof fn}) is not a function." if typeof fn isnt 'function'
      return [] if arr.length is 0

      accumulator = initial
      index = arr.length

      if arguments.length < 3
        index -= 1
        accumulator = arr[index]

      while --index > -1
        accumulator = fn accumulator, arr[index], index, arr
      return accumulator


    # iterateArray :: array, function, any:optional, boolean:optional -> any
    # 用于遍历(reduce/reduceRight)数组
    iterateArray: (arr, fn, reduceRight = false, initial) ->
      throw new TypeError "#{arr} (#{typeof arr}) is not an array." if not isArray arr

      args = [arr, fn]
      args.push(initial) if arguments.length is 4
      if reduceRight
        return fns.reduceRight.apply null, args
      else
        return fns.reduce.apply null, args


    _iterate: (obj, fn, reduceRight = false, initial) ->
      if isArray obj
        args = [obj, fn, reduceRight]
        args.push initial if arguments.length is 4
        return fns.iterateArray.apply null, args

      return fns.iterateObject(obj, fn, initial) if typeof obj is 'object'
      throw new TypeError "#{obj} (#{typeof obj}) is neither an object nor an array."

    # iterate :: object/array, function, any:optional -> any
    # 用于遍历对象或者数组
    # 相当于Array#reduce,不过添加了对object的遍历
    iterate: (obj, fn, initial) ->
      args = [obj, fn, false] # 这里第三个参数是reduceRight
      args.push initial if arguments.length is 3
      return fns._iterate.apply null, args

    # iterateRight :: object/array, function, any:optional -> any
    # 用于遍历对象或者数组
    # 相当于Array#reduceRight
    iterateRight: (obj, fn, initial) ->
      args = [obj, fn, true] # 这里第三个参数是reduceRight
      args.push initial if arguments.length is 3
      return fns._iterate.apply null, args

    # range :: number, number, number, boolean:optional -> [number]
    # 用于生成一个数字区间数字。当 include 为false时,区间不包含end。
    range: (start, end, step = 1, include = true) ->
      if arguments.length is 1
        throw new TypeError "#{start} (#{typeof start}) is not a number." if typeof start isnt 'number'
        result = []
        result.push item for item in [0 ... start]
        return result

      # 以下是使用函数式编程思想实现的对参数类型检查的代码。
      # 这里的关键在于将整个检查过程按照"动作/步骤"的抽象进行拆分,
      # 然后使用compose将多个步骤串联复合成一个"检查"函数。
      # 另外需要注意的是在函数复合中无法使用命令式编程中常用的如`return`这类的方式将程序提前返回。
      # 因此在对每个"步骤"进行实现时要注意判断前一个步骤(函数)的返回值的情况。
      argsMap = {
        'Start value': start
        'End value': end
        'Step value': step
      }

      typeError = fns.throwError TypeError

      checkType = (type) ->
        return (obj) ->
          return {
            result: typeof obj is type
            object: obj
            type
          }

      makeErrorMessage = (checkResult) ->
        if checkResult.result is true
          return true
        else
          return "#{checkResult.object} (#{typeof checkResult.object}) is not a #{checkResult.type}."

      throwTypeError = (prefix) ->
        return (msg) ->
          typeError "#{prefix} #{msg}" if typeof msg is 'string'

      for own prefix, val of argsMap
        check = fns.compose [checkType('number'), makeErrorMessage, throwTypeError(prefix)]
        check val

      result = []
      step *= -1 if start > end and step > 0

      if include
        result.push item for item in [start .. end] by step
      else
        result.push item for item in [start ... end] by step

      return result

    # map :: object/array, function -> object/array
    # 用于对对象或数组进行映射并返回新的对象或数组。
    map: (obj, fn) ->
      typeError = fns.throwError TypeError
      isObject = (o) -> return typeof o is 'object'
      isObjectOrArray = fns.either obj, [isObject, isArray]
      typeError "#{obj} (#{typeof obj}) is neither an object nor an array." if not isObjectOrArray

      result = null
      # 当类型为数组时,使用while来达到最高的性能
      # 类型为Object时,遍历其自身的properties.
      if isArray obj
        result = new Array obj.length
        index = -1
        while ++index < obj.length
          result[index] = fn obj[index], index, obj

      else
        result = {}
        for own key, value of obj
          result[key] = fn key, value, obj

      return result

    # curry :: function, any... -> (any...) -> any
    # 对函数进行柯理化处理并返回柯理化后的函数。
    # 这里需要注意的是,fn函数调用时的参数列表是 "curry后的函数的调用参数 concats curry时的args...参数"。
    # 这一点在设计、实现时的考虑是在于往往进行currying时,原始的函数的参数如果包含回调函数的话往往会在最后(根据习惯),
    # 因此,currying时在闭包中缓存回调函数的话在代码重用上可能会更有帮助。
    curry: (fn, args...) ->
      typeError = fns.throwError TypeError
      typeError "#{fn} (#{typeof fn}) is not a function." if typeof fn isnt 'function'

      return () ->
        cbArgs = [].slice.call arguments
        args = cbArgs.concat args
        return fn.apply null, args

    # curryLeft :: function, any... -> (any...) -> any
    # 强迫症的从参数列表左侧开始的柯理化函数。
    # 与 curry 相对应。
    curryLeft: (fn, args...) ->
      throw new TypeError "#{fn} (#{typeof fn}) is not a function." if not fns.isFunction fn
      return () ->
        cbArgs = [].slice.call arguments
        args = args.concat cbArgs
        return fn.apply null, args


    # toArray :: object, function -> array
    # 用于将object转化为array
    toArray: (obj, fn) ->
      typeError = fns.throwError TypeError
      typeError "#{obj} is already an array." if isArray obj
      typeoError "#{obj} (#{typeof obj}) is not an object." if typeof obj isnt 'object'
      typeError "#{fn} (#{typeof fn}) is not a function." if typeof fn isnt 'function'

      result = []
      for own key, value of obj
        result.push fn(key, value, obj)
      return result

    # toObject :: array, function -> object literal
    # 用于将数组转化成object literal。
    # 转化函数的参数: currentItem, index, array
    # 转化函数应返回一个object literal,并将会被合并到最终返回的新的object literal中。
    toObject: (array, fn) ->
      typeError = fns.throwError TypeError
      typeoError "#{array} (#{typeof array}) is not an array." if not isArray array
      typeError "#{fn} (#{typeof fn}) is not a function." if typeof fn isnt 'function'

      processArray = (result, item, index, arr) ->
        o = fn item, index, arr
        result[key] = value for own key, value of o
        return result

      result = fns.reduce array, processArray, {}
      return result

    # isIndexed :: any -> boolean
    # 用于判断变量是否是可迭代的。
    isIndexed: (obj) -> return isArray(obj) or typeof obj is 'object'

    # allOf :: [any], function:optional -> boolean
    # 用于判断数组中的值是否都为true。
    # 当 fn函数存在时,用其返回值判断。
    allOf: (list, fn) ->
      throw new TyperError "#{list} (#{typeof list}) is neither an object nor an array." if not fns.isIndexed(list)
      if typeof fn is 'function'
        return fns.iterate list, (truth, item) ->
          return truth and fn(item)
        , true
      else
        return fns.iterate list, (truth, item) ->
          result = if typeof item is 'function' then truth and item() else truth and !!item
          return !!result

    # anyOf :: [any], function:optional -> boolean
    # 用于判断数组中的值是否存在true。
    # 当 fn函数存在时,用其返回值判断。
    anyOf: (list, fn) ->
      throw new TyperError "#{list} (#{typeof list}) is neither an object nor an array." if not fns.isIndexed(list)
      if typeof fn is 'function'
        return fns.iterate list, (truth, item) ->
          return truth or fn(item)
        , false
      else
        return fns.iterate list, (truth, item) ->
          result = if typeof item is 'function' then truth or item() else truth or !!item
          return !!result

    # filter :: [any], function -> [any]
    # 用于过滤数组,创建并返回过滤后的新数组。
    # 本质上是对 Array#filter 的函数式包装。
    filter: (list, fn) ->
      throw new TypeError "#{list} (#{typeof list}) is not an array." if not isArray list
      throw new TypeError "#{fn} (#{typeof fn}) is not a function." if typeof fn isnt 'function'
      return [] if list.length is 0
      result = []

      index = -1
      while ++index < list.length
        result.push(list[index]) if fn(list[index]) is true

      return result

    # repeat: positive integer, function -> [any]
    # 用于重复调用fn函数times次。
    # fn函数的参数依次为: currentIndex (0-based), totalTimes
    repeat: (times, fn) ->
      throw new TypeError "#{times} (#{typeof times}) is not a number." if not fns.isNumber times
      throw new Error "#{times} has to be a positive integer." if times < 0 or Math.floor(times) isnt times
      throw new TypeError "#{fn} (#{typeof fn}) is not a function." if not fns.isFunction fn

      return fns.map fns.range(times), (index) -> return fn index, times

    # repeatUntil :: number, function, function -> [any]
    # 用于重复执行fn函数times次,直至condition函数返回非true时终止。
    # condition函数的参数依次为: 本次repeat的buffer数组, currentIndex, totalTimes
    repeatUntil: (times, condition, fn) ->
      throw new TypeError "#{times} (#{typeof times}) is not a number." if not fns.isNumber times
      throw new Error "#{times} has to be a positive integer." if times < 0 or Math.floor(times) isnt times
      throw new TypeError "#{condition} (#{typeof condition}) is not a function." if not fns.isFunction condition
      throw new TypeError "#{fn} (#{typeof fn}) is not a function." if not fns.isFunction fn

      result = []
      for index in [0 ... times]
        temp = [].concat(result)
        val = fn index, times
        temp.push val
        if condition(temp, index, times) is true
          result.push val
        else
          break
      return result

    # pick :: {any}, [string] -> {any}
    # 用于从对象中提取出keys指定的字段并返回新的过滤后的对象。
    pick: (obj, keys) ->
      throw new TypeError "#{obj} (#{typeof obj}) is not an object." if not fns.isObject obj
      throw new TypeError "#{keys} (#{typeof keys}) is neither an array nor a string." if not fns.isArray(keys) and not fns.isString(keys)

      keys = [keys] if fns.isString(keys)
      return fns.toObject keys, (key) ->
        return { "#{key}": obj[key] } if fns.isString(key) and not fns.isEmpty(key)


    # toJqueryElement :: string/[string]/object -> jQuery Element in `elements`'s form
    # 用于将一个或一组CSS selector用jQuery进行选择
    toJqueryElement: (elements) ->
      return elements if fns.isUndefined window.jQuery

      return $(elements) if fns.isString elements

      if fns.isArray elements
        return fns.map elements, (element) ->
          throw new TypeError "#{element} (#{typeof element}) is not a string." if not fns.isString element
          return $ element

      else # if `elements` is an object...
        processPair = (res, name, selector) ->
          throw new TypeError "#{selector} (#{typeof selector}) is not a string." if not fns.isString selector
          res[name] = $ selector
          return res
        result = fns.iterateObject elements, processPair, {}
        return result

    # forEach :: [any], function -> [any]
    # 用于遍历数组,并对每个元素执行fn函数。
    forEach: (list, fn) ->
      throw new TypeError "#{list} (#{typeof list}) is not an array." if not fns.isArray list
      throw new TypeError "#{fn} (#{typeof fn}) is not a function." if not fns.isFunction fn
      index = -1
      len = list.length
      while ++index < len
        break if fn(list[index], index, list) is false

      return list


    # some :: [any], function, function, any -> [any]
    # 用于遍历数组,并对每个元素执行fn函数。直至check函数返回true终止。
    # initial缺省为[]
    # check函数参数列表: currentValue, currentIndex, array
    # fn函数参数列表: accumulator, currentValue, currentIndex, array
    some: (list, check, fn, initial) ->
      throw new TypeError "#{list} (#{typeof list}) is not an array." if not fns.isArray list
      throw new TypeError "#{check} (#{typeof check}) is not a function." if not fns.isFunction check
      throw new TypeError "#{fn} (#{typeof fn}) is not a function." if not fns.isFunction fn

      result = initial or []
      for value, index in list
        result = fn result, value, index, list
        break if check(value, index, list) is true
      return result

    # every :: [any], function, function, any -> [any]
    # 用于遍历数组,并对每个元素执行fn函数。直至返回false终止。
    # initial缺省为[]
    # check函数参数列表: currentValue, currentIndex, array
    # fn函数参数列表: accumulator, currentValue, currentIndex, array
    every: (list, check, fn, initial) ->
      throw new TypeError "#{list} (#{typeof list}) is not an array." if not fns.isArray list
      throw new TypeError "#{check} (#{typeof check}) is not a function." if not fns.isFunction check
      throw new TypeError "#{fn} (#{typeof fn}) is not a function." if not fns.isFunction fn

      result = initial or []
      for value, index in list
        break if check(value, index, list) is false
        result = fn result, value, index, list
      return result


    # clone :: object -> object
    # 用于创建并返回object的深拷贝。
    clone: (obj) ->
      return obj if obj is null or typeof obj isnt 'object'
      temp = obj.constructor()
      for own key, value of obj
        temp[key] = fns.clone value
      return temp

    # extend :: object, [object]/object -> object
    # 对对象a进行扩展并返回新的对象。
    extend: (a, b) ->
      throw TypeError "#{a} (#{typeof a}) is not an object." if not fns.isObject(a)
      b = [b] if not fns.isArray b
      temp = fns.clone a
      temp = fns.reduce b, (temp, o) ->
        throw TypeError "#{o} (#{typeof o}) is not an object." if not fns.isObject(o)
        return fns.iterateObject o, (res, key, value) ->
          res[key] = value
          return res
        , temp
      , temp

      return temp

    # push :: [any], any -> [any]
    # 用于将某个变量push至数组并返回新的数组。
    push: (list, item) ->
      throw new TypeError "#{list} (#{typeof list}) is not an array" if not fns.isArray list
      result = fns.reduce list, (res, o) ->
        res.push o
        return res
      , []
      result.push item

      return result

    # first :: [any] -> any
    # 用于返回数组的首元素
    first: (list, nums) ->
      throw new TypeError "#{list} (#{typeof list}) is not an array." if not fns.isArray list
      return list[0] if not fns.isNumber nums

      throw new Error "Invalid index range: 1 ~ #{nums}. Max: #{list.length}" if nums > list.length
      return fns.reduce fns.range(0, nums - 1), (res, index) ->
        return fns.push res, list[index]
      , []

    # last :: [any] -> any
    # 用于返回数组的末尾元素
    last: (list, nums) ->
      throw new TypeError "#{list} (#{typeof list}) is not an array." if not fns.isArray list
      return list[list.length - 1] if not fns.isNumber nums

      throw new Error "Invalid index range: 1 ~ #{nums}. Max: #{list.length}" if nums > list.length
      return fns.reduce fns.range(list.length - nums, list.length - 1), (res, index) ->
        return fns.push res, list[index]
      , []


    # pluck :: [object], string -> [any]
    # 用于从object数组中抽取出所有的`key`值。
    pluck: (list, key) ->
      throw new TypeError "#{list} (#{typeof list}) is not an array." if not fns.isArray list
      throw new TypeError "'#{key}' (#{typeof key}) is not a valid string." if not fns.isString(key) or fns.isEmpty(key)
      process = (res, item) ->
        value = undefined
        if fns.isObject item
          value = item[key]

        return fns.push res, value
      return fns.reduce list, process, []


    # countBy :: [any], function -> object
    # 用于统计iteratee函数针对list数组每个成员调用后的各个返回值的次数。
    countBy: (list, iteratee) ->
      throw new TypeError "#{list} (#{typeof list}) is not an array." if not fns.isArray list
      throw new TypeError "#{iteratee} (#{typeof iteratee}) is not a function." if not fns.isFunction iteratee

      return undefined if list.length is 0
      result = {}
      index = -1
      while ++index < list.length
        res = iteratee list[index]
        if result[res]?
          result[res] += 1
        else
          result[res] = 1
      return result

  }

  window.$fun = fns
