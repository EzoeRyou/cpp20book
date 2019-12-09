## 未評価文脈におけるラムダ式

C++20では未評価文脈におけるラムダ式が許容される制限緩和が行われた。

以下のようなコードがC++17では違法だったが、C++20では合法になる。

~~~cpp
std::size_t closure_object_size = sizeof([]{}) ;
using closure_object_type = decltye([]{}) ;
~~~

この変更はとても重要で、平均的なC++プログラマーも直接恩恵を受けるのだが、前提となる知識が多い。

まず大前提の知識として、ラムダ式によって生成されるクロージャーオブジェクトは、たとえラムダ式が同じトークン列であったとしても、別の型になる仕様がある。

~~~cpp
auto a = []{} ;
auto b = []{} ;

// false
bool c = std::is_same_v< decltype(a), decltype(b) > ;
~~~

`a, b`は全く同じトークン列のラムダ式から生成されたクロージャーオブジェクトだが、それぞれ別の型を持つ。したがって最後の`is_same`は`false`になる。

### 未評価文脈

未評価オペランド(unevaluated operand)の中の式は評価されない。未評価文脈とは未評価オペランドの中の式という意味だ。未評価オペランドは式を書くことが目的で評価することが目的ではない。

未評価オペランドとして最も昔からあるものがsizeofのオペランドだ。sizeofのオペランドは評価されない。

~~~cpp
// 副作用を伴う関数
int g{} ;
int f()
{
    std::cout << "hello"sv ;
    ++g ;
    return g ;
}

int main ()
{
    // 未評価オペランド
    std::cout << sizeof( f() ) ;
}
~~~

この例では、未評価オペランドに`f()`という式がある。これは関数fを関数呼び出しする式だ。関数fは標準出力とグローバル名前空間スコープの変数gをインクリメントするが、その内容は評価されない。sizeofは未評価オペランドに記述された式を評価した結果の型のサイズを返す式で、式は評価しない。

sizeofは式を評価しないので、この場合、関数fは定義されている必要すらない。

~~~c++
int f() ;

// OK
// sizeof(int)と同じ
std::size_t s = sizeof( f() ) ;
~~~

定義されていない関数を呼び出すことはできないが、sizeofは未評価オペランドなので、関数は定義されている必要がない。

### ラムダ式と関数呼び出し式の違い

ラムダ式はクロージャーオブジェクトを生成するための式だ。ラムダ式を評価した結果のクロージャーオブジェクトはそのまま関数呼び出し式が適用できる。

~~~cpp
// ラムダ式
// 評価した結果の型はユニークなクロージャーオブジェクトの型
[]{} ;
// ラムダ式の結果に関数呼び出し式を適用
// 最後の()が関数呼び出し式
// 評価した結果の型はvoid
[]{}() ;
~~~

この違いを認識する必要がある。未評価オペランドに、ラムダ式のみを書くのと、ラムダ式と関数呼び出し式を書くのは異なる。

上記のコードの文法が理解できない場合は、以下のコードを参考にするとよい。同じ文法だ。

~~~c++
// 関数
void f( int x, int y ) ;
// 関数名に対する関数呼び出し式の適用
f ( 1, 2 ) ;
// ラムダ式
[]( int x, int y ) {} ;
// ラムダ式によって生成されたクロージャーオブジェクト
// に対する関数呼び出し式の適用
[]( int x, int y ) {} ( 1, 2 ) ;
~~~

### 未評価オペランドの一覧

C++20において未評価オペランドを持つ文脈は6箇所ある。

+ requires式
+ typeid
+ sizeof
+ noexcept演算子
+ decltype
+ requires-clause

それぞれについてラムダ式を書いた場合を見ていく。

#### requires式

requires式の中に書かれた式は未評価オペランドだ。requires式は式を書くのが目的であって、評価するのが目的ではないからだ。

~~~cpp
constexpr bool b = requires { []{} ; } ;
~~~

requires式の中の未評価オペランドにラムダ式を書くことはできる。ただし、ラムダ式の中にsubstitution failureを引き起こす依存名を書くと、ハードエラーになる。SFINAE(Substitution Failure Is Not An Error)にはならない。SFIAE(Substituion Failure Is An Error)だ。

~~~c++
// 制約テンプレート
template < typename T >
    requires requires
    {
        []{ T::value ; } ;
    }
void f() { }

// 非制約テンプレート
template < typename T >
void f() { }

struct S { inline static int value = 0 ; } ;

int main()
{
    // エラー、SFINAEではない
    f<int>() ;
    // OK、制約テンプレートが選ばれる
    f<S>() ;
}
~~~

上記の制約テンプレートが以下のようになっていた場合、

~~~c++
template < typename T >
    requires requires { T::value ; }
void f() { }
~~~

エラーは起こらない。テンプレートの実体化とオーバーロード解決の結果、`f<int>`はSubstitution Failureだが、SFINAEによりエラーにはならない。そして制約を満たさないため非制約テンプレートが選ばれる。`f<S>`はSubbstitution Failureもなく制約を満たすため制約テンプレートが選ばれる

#### typeid

typeidのオペランドの型がポリモーフィック型ではない場合、未評価オペランドになる。

~~~cpp
// クロージャーオブジェクトの型
typeid( []{} ) ;
// void
// クロージャーオブジェクトの呼び出し
// この場合の戻り値の型はvoid
typeid( []{}() ) ;
~~~

クロージャーオブジェクトがポリモーフィック型になることはないので、typeidの中にラムダ式だけを書いた場合は必ず未評価オペランドになる。

ただし、クロージャーオブジェクトの型はそれぞれ異なるので、同じトークン列のラムダ式を未評価オペランドの中に書いた2つのtypeidの返す`type_info`は等しくない。

~~~cpp
decltype(auto) a = typeid([]{}) ;
decltype(auto) b = typeid([]{}) ;
// false
bool b = a == b ;
~~~

もちろん、ひとたび生成された特定のクロージャーオブジェクトの型が変わることはない。

~~~cpp
auto lambda = []{} ;
decltype(auto) a = typeid(lambda) ;
decltype(auto) b = typeid(lambda) ;
// true
bool b = a == b ;
~~~

#### sizeof

sizeofのオペランドは未評価オペランドだ。sizeofのオペランドにラムダ式を書いた場合、クロージャーオブジェクトのサイズを返す。

~~~cpp
std::size_t closure_object_size = sizeof( []{} ) ;
~~~

これは以下のようなコードと似たような効果がある。

~~~cpp
// ラムダ式が生成するクロージャーオブジェクトの模倣
struct closure_object
{
    void operator()() const {} ;
} ;

std::size_t closure_object_size = sizeof( closure_object{} ) ;
~~~

ラムダ式を関数呼び出しした場合は、式を評価した結果の型のsizeof、つまり戻り値の型になる。


~~~c++
// エラー、sizeof(void)
sizeof( []{}() ) ;
// sizeof(int)と同じ
sizeof( []{ return 0 ;}() ) ;
// sizeof(double)と同じ
sizeof( []{ return 0.0 ; }() ) ;
~~~

これは以下のようなコードと同じだ。

~~~c++
void f1() ;
int f2() ;
double f3() ;
// エラー、sizeof(void)
sizeof( f1() ) ;
// sizeof(int)と同じ
sizeof( f2() ) ;
// sizeof(double)と同じ
sizeof( f3() ) ;
~~~

ラムダ式の生成するクロージャーオブジェクトのサイズは実装に依存する。

例えば筆者の環境では、ステートレスラムダのサイズは1になる。

~~~cpp
std::size_t s = sizeof( []{} ) ;
~~~

キャプチャーを行うラムダ式の場合、クロージャーオブジェクトがキャプチャーする変数のオブジェクトのサイズとアライメント調整の結果のサイズになる。

~~~cpp
int main()
{
    int i{} ;
    auto size = sizeof( [=]{ i ; } ) ;
}
~~~

筆者の環境では変数`size`は4になる。これは、筆者の環境の`sizeof(int)`は4であることと、int型をコピーして持つよう生成されたクロージャーオブジェクトのサイズが4だということだ。

これがリファレンスキャプチャーの場合、

~~~c++
auto size = sizeof( [&]{ i ; } ) ;
~~~

筆者の環境では`size`は8になる。筆者の環境ではアドレス長が8バイトあるからだ。

複数の変数をキャプチャーする場合、アライメント調整も考慮しなければならない。

~~~cpp
int main()
{
    char c{} ;
    int i{} ;
    auto ci_size = sizeof(c) + sizeof(i) ;
    auto lambda_size = sizeof( [=]{ c; i ; } ) ;
}
~~~

筆者の環境では、`ci_size`は5になるが、`lambda_size`は8になる。

これらのことはラムダ式に限った話ではなく、クラスのサイズにも共通の話だ。

#### noexcept演算子

noexcept演算子のオペランドは未評価式だ。

~~~cpp
bool b = noexcept( []{} ) ;
~~~

C++11で追加されたnoexcept演算子は、オペランドの式がpotentially-throwing(潜在的に例外を投げる)かどうかを調べる。オペランドの式がpotentially-throwingならばtrue、そうでない場合はfalseを返す。

「潜在的に例外を投げる」とは実際に例外を投げるコードパスがあるという意味ではない。C++の規格は簡易的な「潜在的に例外を投げる」という条件を規定している。

潜在的に例外を投げる式であるかどうかは、大まかに以下のようにまとめられる。

例外指定が`noexcept`, `noexcept(true)`以外の関数は潜在的に例外を投げる例外指定を持つ。

~~~~cpp
// 潜在的に例外を投げる例外指定
void a() ;
void b() noexcept(false) ;

// 潜在的に例外を投げる例外指定ではない
void c() noexcept ;
void d() noexcept(false) ;
~~~

これを踏まえた上で、ある式が「潜在的に例外を投げる」というのは、以下の条件のいずれかを満たした場合だ

+ 式は関数を呼び出し、その関数が潜在的に例外を投げる例外指定である
+ 式は暗黙に呼び出す関数が潜在的に例外を投げる
+ 式はthrow式
+ 式はdynamic_castで、リファレンスキャストであり、実行時チェックを必要とする
+ 式はtypeidでポリモーフィックなクラス型へのポインターに単項*演算子を適用した
+ 式は上記の式をサブ式に含む

クラスの暗黙に生成されるコンストラクターは、その初期化に潜在的に例外を投げる式が含まれる場合は潜在的に例外を投げる例外指定を持つ。

~~~cpp
// 潜在的に例外を投げる例外指定ではないコンストラクター
struct X { } ;

// 潜在的に例外を投げる例外指定のコンストラクター
// std::stringによる
struct Y
{
    std::string s ;
} ;
~~~

これらの前提知識を踏まえてnoexcept演算子のオペランドにラムダ式を書いた場合について考えていく。

ラムダ式が何もキャプチャーをしないステートレスラムダの場合、`noexcept`は`true`になる。

~~~cpp
bool b = noexcept([]{}) ;
~~~

ラムダ式の生成するクロージャーオブジェクトのコンストラクターは潜在的に例外を投げる例外指定を持たないからだ。

ラムダ式がコピーキャプチャーをする場合、`noexcept`の結果はキャプチャーする変数のコピーコンストラクターの例外指定が影響する。

~~~cpp
// コピーコンストラクターが
// 潜在的に例外を投げる例外指定を持たない型
struct no_throw { } ;
// コピーコンストラクターが
// 潜在的に例外を投げる例外指定を持つ型
struct yes_throw
{
    yes_throw() = default ;
    yes_throw( const yes_throw & ) { }
} ;


int main ()
{
    no_throw no ;
    // true
    bool n = noexcept( [=]{ no ; } ) ;

    yes_throw yes ;
    // false
    bool y = noexcept( [=]{ yes ; } ) ;
}
~~~

コピーキャプチャーをするラムダ式が生成するクロージャーオブジェクトはキャプチャーする変数のコピーコンストラクターを暗黙に呼び出す。そのコピーコンストラクターの例外指定が影響する。

noexcept演算子のオペランドの中に書いたラムダ式に関数呼び出し式を適用すると、関数呼び出し式の結果になる。例外指定を書かない場合、潜在的に例外を投げる式となる。

~~~cpp
// false
bool b = noexcept( []{}() ) ;
~~~

ラムダ式に例外指定を書くことで、潜在的に例外を投げる関数指定ではない関数にできる。

~~~cpp
// true
bool b = noexcept( []() noexcept {}() ) ;
~~~

#### decltype

プレイスホルダーのdecltypeのオペランドは未評価オペランドだ。型指定子decltypeはオペランドの式を評価した結果の型になる。

decltypeのオペランドにラムダ式を書いた場合、ラムダ式が生成するクロージャーオブジェクトの型になる。

~~~cpp
// クロージャーオブジェクトの型
using closure_object_type = decltype( []{} ) ;
~~~

ラムダ式はたとえ同じトークン列でも、それぞれユニークな型のクロージャーオブジェクトを生成する。そのため同じトークン列のラムダ式をオペランドに書いたdecltypeはそれぞれ別の型になる。

~~~c++
using a = decltype( []{} ) ;
using b = decltype( []{} ) ;
// false
bool b = std::is_same_v<a, b> ;
~~~

decltypeのオペランドの中でラムダ式を関数呼び出しした場合は、普通の関数を呼び出した場合と同じだ。

~~~c++
// void
using a = decltype( []{}() ) ;
// int
using b = decltype( []{ return 0 ; }() ) ;
// double
using c = decltype( []{ return 0.0 ; }() ) ;
~~~

これは以下のコードと同じだ。

~~~c++
auto l1(){ } 
auto l2(){ return 0 ; }
auto l3(){ return 0.0 ; }
// void
using a = decltype( l1() ) ;
// int
using b = decltype( l2() ) ;
// double
using c = decltype( l3() ) ;
~~~

ラムダ式を未評価式の文脈で使えるようにする制限緩和で、最も実用的なのは、decltypeのオペランドに書くラムダ式だ。この制限緩和と、同じくC++20に追加されたステートレスラムダのデフォルト構築を組み合わせると、とても便利なコードが書ける。ラムダ式をデフォルト構築可能な型としてテンプレートに渡せるのだ。

~~~cpp
struct person
{
    std::string name ;
    std::string address ;
} ;

int main()
{
    std::set< person, decltype([]( auto && a, auto && b ) { return a.name < b.name ; }) > name_sorted_set ;
}
~~~

ラムダ式が未評価式の文脈で使えるようになったので、decltypeの中にラムダ式を書いて`std::set`の比較関数オブジェクトの型として渡せるようになった。しかも、ステートレスラムダ式はデフォルト構築可能なので、別途、値としての関数オブジェクトをコンストラクターに渡す必要はない。

#### requires-clause

requires-clauseは未評価式だが、これは通常の式とは文法が少し違っているので、括弧で囲まなければならない。そして、ラムダ式を評価した結果の型はクロージャーオブジェクトの型でbool型ではないので、ラムダ式だけを書くことはできない。カンマ演算子を使うか、boolを返すラムダ式を関数呼び出しする必要がある。

~~~cpp
template < typename T >
    requires ([]{}, true) && ([]{return true ;}())
void f() ;
~~~

どちらも実用上の意味はない。
