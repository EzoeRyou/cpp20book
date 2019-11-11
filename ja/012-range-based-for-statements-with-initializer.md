## 初期化子つきrange-based for

Range-based forに初期化子を書けるようになった。

~~~c++
for ( auto x = {1,2,3,4,5} ; auto i : x )
    std::cout << i ;
~~~

このコードは以下のような構造になっている。

~~~c++
for (                       // range-based for文
    auto x = {1,2,3,4,5} ;  // 初期化子
    auto i                  // for-range宣言
    :
    x )                     // for-range初期化子
std::cout << i ;            // range-based for文の中の文
~~~

`x`の型は`std::initializer_list<int>`で、`i`の型は`int`だ。

通常のfor文やif文にあるような初期化子をrange-based for文にも書けるようにしたのがこの機能だ。

~~~c++
if  ( auto x = expr ; x ) ...
for ( auto x = expr ; condition ; expr ) ... 
for ( auto x = expr ; auto i : x ) ...
~~~

具体的な使い方としては、メンバー関数`range`がRangeを返すような値を返す関数`f()`があった場合に、関数`f()`を呼び出した結果をrange-based for文で要素をイテレートしたい場合、従来ならば、

~~~c++
// メンバー関数rangeがRangeを返すような値となるクラス
struct R
{
    std::vector<int> v ;
    std::vector<int> & range()
    { return v ; } 
} ;
R f() ;

int main()
{
    {
        auto r = f() ;
        for ( auto i : r.range() )
            std::cout << i ;
    }
}
~~~

のように書いていたが、range-based for文に初期化子が書けるようになったので、

~~~c++
for ( auto r = f() ; auto i : r.range() )
    i ;
~~~

と書くことができる。

ここで、

~~~c++
for ( auto i : f().range() )
    std::cout << i ;
~~~

と書くのは誤りだ。なぜならば一時オブジェクトの寿命が付きているからだ。

一時オブジェクトの寿命はその一時オブジェクトを生成した完全式の評価の終わりまでだ。ただし、一時オブジェクトがリファレンスに束縛された場合は、そのリファレンスの寿命似合わせて一時オブジェクトの寿命も延長される。

`f()`を評価した結果の一時オブジェクトはリファレンスに束縛されていないので、一時オブジェクトの寿命は完全式の評価が終了した時点で尽きる。具体的に説明すると、このrange-based forのfor-range初期化子は以下のようなコードのシンタックスシュガーとなるが、

~~~c++
auto && range = f().range() ;
auto begin = range.begin() ;
auto end = range.end() ;
for ( ; begin != end ; ++begin ) {
    auto i = * begin ;
    std::cout << i ;
}
~~~

リファレンスrangeに束縛されている一時オブジェクトは、`f()`を評価した結果の一時オブジェクト(Rのオブジェクト)に対してメンバー関数`range()`呼び出しを評価した結果の一時オブジェクトだ。束縛されているのはRの一時オブジェクトの中のサブオブジェクト`std::vector<int>`へのlvalueリファレンスだが、Rの一時オブジェクトはリファレンスに束縛されていないので、完全式、この場合`f().range()`を評価し終わったタイミングで寿命が付きてしまう。

そのために一度リファレンスに束縛して寿命延長するか、実際のオブジェクトを構築しなければならないが、

~~~c++
{
// オブジェクトを構築
auto r = f() ;
// 寿命は付きない
for ( auto i : r.range() )
    ...
} // これ以降rは必要がないのでブロックスコープで囲む
~~~

そのための記述は面倒なので、

~~~c++
for ( auto r = f() ; auto i : r.range() )
    ...
~~~

range-based for文に初期化子が追加された。
