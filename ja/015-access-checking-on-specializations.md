## 特殊化におけるアクセスチェック

以下のようなコードを考える

~~~c++
template < typename T >
struct traits ;

class class_ {
    // プライベートなネストされたクラス
    class impl ;
} ;

// 明示的特殊化
template < >
struct trait< class_::impl > ;
~~~

このコードはC++17までは規格の文面を厳密に解釈するとprivateなネストされたクラスを使っているので違法であった。しかし、現実の主要なC++コンパイラーはすべてこのコードにアクセスチェックをせず通してしまうし、またこのようなコードには利用価値があるので、C++20では規格で正式に合法化された。

部分的特殊化も合法化された。

~~~c++
template < typename T >
struct traits ;

class class_ {
    template < typename T >
    struct impl ;
} ;

template < typename U >
struct trait< class_::impl<U> > ;
~~~


