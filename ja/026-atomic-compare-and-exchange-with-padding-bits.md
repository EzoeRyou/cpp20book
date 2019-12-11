## アトミック操作のcompare-and-exchangeでパディングのある場合の挙動の変更

アトミック操作ライブラリにはcompare-and-exchangeという操作がある。この関数にはフリー関数版とメンバー関数版と、さらにstrong/weakとメモリーオーダーを実引数に取るオーバーロード関数が多数あるが、問題を簡単にするため、アトミック操作のことはまず考えず、以下のような形を考える。

~~~c++
template < typename T >
bool compre_exchange( T & current, T & expected, T desired ) ;
~~~

compare_exchangeは以下のような挙動をする。

+ currentとexpectedを比較し、等しければcurrentの値をdesiredにする
+ そうでない場合、expectedの値をcurrentにする
+ 戻り値は比較の結果

コードで書くと以下のような形になる。

~~~c++
template < typename T >
bool compre_exchange( T & current, T & expected, T desired )
{
    bool result = ( current == expected ) ;
    if ( result )
        current = desired ;
    else
        expected = current ;

    return result ;
}
~~~

このような一連の操作をアトミックに行うのがcompare-and-exchangeだ。この操作はアトミックに行えると、排他的制御のためのスピンロックやロックフリーデータ構造を作るための操作など様々な実装に応用できる。

ただし、C++17のアトミック操作のcompare-and-exchangeは、以下のようなコードに近い挙動になっている。


~~~c++
template < typename T >
bool compre_exchange( T & current, T & expected, T desired )
{
    bool result = ( std::memcmp( &current, &expected, sizeof(T) == 0 ) ;
    if ( result )
        std::memcpy( &current, &desired, sizeof(T) ) ;
    else
        std::memcpy( &expected, &current, sizeof(T) ) ;

    return result ;
}
~~~

比較には`operator ==`ではなく`std::memcmp`を使う。値をストアするには代入演算子ではなく`std::memcpy`を使う。つまり、バイト列で比較をして、バイト列でコピーをする。

このような低級な挙動になっている理由は、ハードウェアのアトミック操作命令がこのようになっているためだ。

この挙動では問題になる場合がある。

+ pading
+ 浮動小数点数

### パディング

パディングはオブジェクトの値を表現するためのバイト列の中に、使われていないビット列やバイト列が存在することだ。例えば以下のようなクラス型を考える。

~~~cpp
struct S
{
    char c ;
    int i ;
} ;
~~~

筆者の環境では、`sizeof(char) == 1`かつ`sizeof(int) == 4`かつ`alignof(int) == 4`だ。int型のアライメント要求は4バイトなので、コンパイラーはアライメント調整のためにパディングバイトを設けなければならない。その結果、筆者の環境では`sizeof(S) == 8`となり、クラスSのメモリレイアウトは実際には以下のようになる。

~~~cpp
struct S
{
    char c ;
    std::byte paddings[3] ;
    int i ;
} ;
~~~

paddingsはアライメントを調整するためだけに存在するバイト列だ。このバイト列は存在するが使われない。しかし、バイト列が存在するということは、その値を変えることができるということだ。パディングバイトを変更してみよう。

~~~c++
struct S
{
    char c ;
    int i ;
    // メンバーごとの比較を自動生成
    bool operator ==( const S & ) const = default ;
} ;

int main()
{
    S a{'x', 123} ;
    S b = a ;

    std::byte * ptr = reinterpret_cast<std::byte *>(&b) ;
    // パディングバイトを変更
    ptr[1] = std::byte( int(ptr[1]) + 1 ) ;

    // 比較演算子による比較
    // true
    bool c = ( a == b ) ;
    // 生のバイト列による比較
    // false
    bool d = ( std::memcmp( &a, &b, sizeof(S) ) == 0 ) ;
}
~~~

このように、パディングバイトは通常のメンバーごとの比較では比較されないが、生のバイト列としては存在するので、比較演算子による比較と`std::memcmp`による比較の結果が異なる。

### 浮動小数点数

浮動小数点数のフォーマットは実装依存だが、最も普及しているIEE 754では、値を比較すると等しいと評価されるが生のバイト列が異なる表現とNaNがある。

IEEE 754では`+0.0`と`-0.0`は別のバイト列で表現されるが、比較すると等しいと評価される。

~~~cpp
int main()
{
    double a = +0.0 ;
    double b = -0.0 ;
    // true
    bool c = (a == b) ;
    // false
    bool d = (std::memcmp( &a, &b, sizeof(double)) == 0 ) ;
}
~~~

### C++20での変更

C++20ではパディングの問題が修正された。パディングを含む型の値の比較は単なる値を表現する生のバイト列ではなく値の比較により行われることになった。


浮動小数点数の挙動は変わらないので注意が必要だ。


