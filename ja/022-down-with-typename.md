## 文脈上型であることが明らかな場所での型としての依存名にtypename不要の制限緩和

C++20では依存名を型として使う際、文脈上型しか書けない一部の場所ではtypenameキーワードが不要になった。

~~~cpp
template < typename T >
// OK
T::type * f()
{
               // OK
    return new T::type ;
}
~~~

### 依存名

C++のテンプレートでは、依存名という概念が存在する。依存名とは、テンプレート仮引数に依存する名前だ。例えばテンプレート仮引数名`T`がある場合、`T::type`は依存名だ。他にも`S<T>::type`も依存名になる。

C++では実装上の都合で、テンプレートは宣言時に、それぞれの名前について、型なのか値なのかを判断する。例えば、

~~~c++
X * Y ;
~~~

というコードは、もし`X`が型であれば、「Xへのポインター型の変数Yの宣言文」だ。`X`が値であれば「XとYに二項演算子operator *を適用する式文」という意味になる。

型テンプレート仮引数`T`に対して以下のようなコードがある場合、

~~~c++
T::type * x ;
~~~

C++のコンパイラーは、このコードだけでは`T::type`が型なのか値なのかがわからない。なぜならば、`T::type`は依存名なので、型にも値にもなりうるからだ

~~~c++
// T::typeが型である場合
struct A
{
    using type = int ;
} ;

// T::typeが値である場合
struct B
{
    constexpr static int type = 0 ;
} ;
~~~
C++では、この問題を解決するために、依存名はデフォルトで値ということにしている。そのため型テンプレート仮引数`T`に対して以下のようなコードがある場合、

~~~c++
T::type * x ;
~~~

これは「`T::type`という値と`x`という値に対して二項演算子operator *の適用した式文」という意味になる。

これは非型テンプレート仮引数でも同じだ。

~~~c++
template < int N >
struct S
{ using type = int ; } ;

template < int N >
void f()
{
    S<N>::type x ;
}
~~~

以下のようなコードは一見すると`S<N>::type`は型であることが明らかだと思うかも知れない。しかしテンプレートは明示的特殊化や部分的特殊化ができるので、いかのような明示的特殊化が後から追加されるかも知れない。

~~~c++
template < >
struct S<0>
{
    constexpr static int type = 0 ;
} ;
~~~

テンプレートの宣言時に、依存名は名前検索されない。依存名は単に型か値かを判断されることしかしない。`S<N>::type`は依存名なので、宣言時に名前検索されず、テンプレートが実体化されたときに初めて名前検索される。

依存名を型として解釈してほしい場合、明示的にtypenameキーワードを依存名の前に書かなければならない。

~~~c++
typename T::type * x ;
~~~

これは「`T::type`という型へのポインター型の変数xの宣言文」という意味になる。

そのため、C++17では型として解釈してほしい依存名にはすべてtypenameキーワードをつける必要があった。

~~~cpp
template < typename T >
typename std::add_pointer< typename T::type >::type f() ;
~~~

上記のコードのふたつのtypenameは一見冗長に見えるが、どちらも文法上必要だ。なぜならば`T::type`は依存名なので型であることを明示するためにtypenameキーワードが必要だし、`add_ponter<テンプレート実引数>::type`はテンプレート実引数である`T::type`が依存名なので、同じく依存名になり、型であることを明示するためにtypenameキーワードが必要になる。

C++17では、基本クラスとメンバー初期化子に限って、依存名でも型とみなす例外的なルールがあった。

~~~cpp
template < typename T >
struct S : T::type // 型とみなす
{
    // 型とみなす
    S() : T::type()
    { }
} ;
~~~

これはその文脈では型しか書けないためだ。

しかし、C++には他にも文脈上、型しか書けない箇所が多数存在する。上の`std::add_pointer`の例にしてもそうだ。`std::add_pointer`はすでに宣言されていて、第一テンプレート仮引数は型テンプレート仮引数であることが明らかになっている。とすれば、`add_pointer`に対する実引数は、それが何であれ、文脈上は型以外にありえない。

~~~c++
// エラー、文法上ありえない
// is_pointerの第一テンプレート仮引数は型テンプレート仮引数
std::is_pointer<123>::type
~~~

`is_pointer<...>::type`が書かれている場所は、関数の戻り値の型を書くべき文法上の場所である。ここに値を書くことはありえない。

~~~c++
// エラー、文法上ありえない
// 関数の戻り値の型を書くべき場所に値を書くことはできない
123 f() ;
~~~

C++20では、文脈上型しか書けない場所に書かれた依存名は型であるとみなすという大幅な制限緩和が行われた。

### typenameを明示的に書かなくてもよい文脈

C++20では基本クラスとメンバー初期化子に加えて、以下の文脈では依存名を型だとみなすようになった。型だとみなす文脈では明示的にtypenameキーワードを書く必要はない。従来どおり書いてもよい。

#### new

~~~c++
template < typename T >
void f()
{
    // OK、T::typeは型とみなす
    new T::type ;
}
~~~

#### エイリアス宣言

~~~c++
template < typename T >
void f()
{
    // OK、T::typeは型とみなす
    using type = T::type ;
}
~~~

#### 戻り値の型の後置

~~~c++
template < typename T >
            // OK、T::typeは型とみなす
auto f() -> T::type ;
~~~

#### テンプレート型仮引数のデフォルト実引数

~~~c++
                       // OK、T::typeは型とみなす
template < typename T, typename U = T::type >
void f() ;

~~~

#### static_cast/const_cast/reinterpret_cast/dynamic_cast

~~~c++
template < typename T >
void f()
{
    // OK、T::typeは型とみなす
    static_cast<T::type>(0) ;
    const_cast<T::type>(0) ;
    reinterpret_cast<T::type>(0) ;
    dynamic_cast<T::type>(0) ;
}
~~~

#### 名前空間スコープにおける単純宣言と関数定義

~~~c++
// グローバル名前空間スコープ

// 単純宣言
template < typename T >
// OK、T::typeは型とみなす
T::type variable ;

// 関数定義
template < typename T >
// OK、T::typeは型とみなす
T::type f() { }
~~~

「関数定義」に注意。関数宣言は型だとみなす文脈ではない。そもそも、文法が曖昧になり変数宣言になるので、typenameキーワードを使わずに依存名を使ったまま関数宣言を書くことはできない。

~~~cpp
// T::type型で初期化子が(T::type)である変数fの宣言
template < template T >
T::type f( T::type ) ;
~~~

これは変数の宣言だ。関数の宣言を書くには、typenameキーワードを使って明示的に依存名を型であると明示する必要がある。

~~~cpp
// T::type型を仮引数にとりT::type型を戻り値の型とする関数fの宣言
template < typename T >
typename T::type f( typename T::type ) ;
~~~

#### メンバー宣言

~~~c++
template < typename T >
struct S
{
    // OK、T::typeは型とみなす
    T::type member ;
} ;
~~~

### メンバー宣言の中の仮引数宣言

メンバー宣言、つまりメンバー関数の宣言の中の仮引数宣言は型であるとみなされる。

~~~c++
template < typename T >
struct S
{
    // OK、T::typeは型とみなす
    void f( T::type ) ;
} ;
~~~

これはメンバー宣言だけだ。名前空間スコープの中の関数の宣言では文脈上型にはならない。すでに説明したように、変数宣言として扱われる。

もう一つ例外的なルールがある。メンバー宣言の中のデフォルト実引数の中の仮引数宣言では型であるとはみなされない。これはデフォルト実引数の中にラムダ式を書き、そのラムダ式の本体の中に依存名を使った場合が当てはまる。

~~~cpp
template < typename T >
struct S
{
    // エラー、ラムダ式の中のT::typeは値とみなす
    void f( T::type x = []( T::type x ){ return T::type{} ; }( T::type{} ) ) ;
} ;
~~~

正しくは以下のようにtypenameキーワードを使って型であると明示しなければならない


~~~cpp
template < typename T >
struct S
{
    // このT::typeは型とみなす
    void f( T::type x =
        // このT::typeはデフォルトで値とみなされるのでtypenameキーワードが必要
        []( typename T::type x ){ return typename T::type{} ; }( typename T::type{} ) ) ;
} ;
~~~

#### 関数名が修飾名の関数宣言の仮引数宣言

関数名が修飾名の場合の関数宣言の仮引数宣言では、依存名は型とみなされる。

~~~c++
namespace NS {
    template < typename T >
    // typenameキーワードが必要
    void f( typename T::type ) ;
}

// 上のNS::fの再宣言
template < typename T >
// typenameキーワードは必要ない
void NS::f( T::type ) ;
~~~

この場合も、デフォルト実引数の中の仮引数宣言では依存名は型だとみなされない。

#### ラムダ式の仮引数宣言

~~~c++
int main()
{
    // OK、T::typeは型とみなす
    []< typename T >( T::type x ){ return x ; } ;
}
~~~

この場合も、デフォルト実引数の中の仮引数宣言では依存名は型だとみなされない。
