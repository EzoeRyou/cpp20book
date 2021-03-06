## 指示初期化子(designated-initializers)

指示初期化子(designated-initializers)はC99で追加された機能だ。C++20にはC99よりも機能を制限した指示初期化子が追加された。

指示初期化子とは、クラスのオブジェクトのリスト初期化において、クラスの非staticデータメンバーの名前を記述できる機能だ。

~~~cpp
struct S { int x, y, z ; } ;

// S s{1,2,3}と同じ
S s1 { .x = 1, .y = 2, .z = 3 } ;
S s2 = { .x = 1, .y = 2, .z = 3 } ;
~~~

文法は、ドット(.)に続いて非staticデータメンバーの識別子を書き、`=`を書き、初期化の式を書く。

~~~
{ . 識別子 = 式, ... }
~~~

C++20の指示初期化子は、C99の指示初期化子の機能制限版だ。

識別子はクラスの非staticデータメンバー名を宣言順に書かなければならない。

~~~c++
struct S { int x, y ; } ;

// C99では合法
// C++20では違法、宣言順ではない
S s{ y. = 0, x = 0 }
~~~

C99では宣言順に書かなくてもよいが、。C++20では宣言順に書かなければならない。

C99では配列を指示初期化できるが、C++20ではできない。

~~~c++
// C99では合法
// C++20では違法
int a[3] = { [1] = 1, [0] = 2, [2] = 3 } ;
~~~

C99では指示初期化子のネストができるが、C++20ではできない。

~~~c++
struct A { int x ; } ;
struct B { struct A a ; } ;

// C99では合法
// C++20では違法
B b{ .a.x = 0 } ;
~~~

C99では指示初期化子と通常の初期化子を混ぜることができるが、C++20ではできない。

~~~c++
struct S { int x, y ; } ;

// C99では合法
// C++20では違法
S s{ .x = 0, 1 } ;
~~~

このような制限がある理由としては、C++ではオブジェクトの破棄は構築の逆順に行われ、初期化リストの要素の評価は表記順に行われるために、指示初期化子でも宣言順に記述しなければならない制限が加えられた。配列の指示初期化子はラムダ式と文法が衝突するために採用されなかった。指示初期化子のネストはC99でもまれにしか使われていないので採用されなかった。
