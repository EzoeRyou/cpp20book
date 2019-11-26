## デフォルト構築可能かつ代入可能なステートレスラムダ

ステートレスラムダとは、キャプチャーをしないラムダ式のことだ。

~~~cpp
int main()
{
    int x { } ;
    // キャプチャーをするラムダ
    [=]{ return x ; } ;
    [&]{ return x ; } ;
    [x]{ return x ; } ;
    [&x]{ return x ; ] ;
    [ y = x ]{ return y ; } ;

    // キャプチャーをしないラムダ
    []{ return 0; }
}
~~~

キャプチャーをしないラムダ式を評価した結果のクロージャーオブジェクトは特別に関数へのポインターへの変換関数を持っている。

~~~cpp
int main()
{
    // ラムダ式
    auto x = [](int x) -> int { return x ; } ;
    // 関数へのポインターへの変換関数
    auto (*p)(int) -> int = x ;
    // 関数へのポインターを経由した関節呼び出し
    p(0) ;
}
~~~

C++17までは、ラムダ式を評価した結果のクロージャーオブジェクトはデフォルト構築可能ではなく、代入可能でもなかった。

~~~c++
int main()
{
    auto f = []{} ;
    // エラー、デフォルト構築できない
    decltype(f) g ;
    // エラー、代入できない
    g = f ;
}
~~~

テンプレートを使ったジェネリックなコードでは、型が普通に振る舞うこと、つまりデフォルト構築可能であることや、代入可能であることはとても重要だ。そこでC++20ではステートレスラムダを評価した結果のクロージャーオブジェクトはデフォルト構築可能かつコピー代入可能かつムーブ代入可能になった。

~~~c++
int main()
{
    auto f = []{} ;
    // OK、デフォルト構築可能
    decltype(f) g ;
    // OK、コピー代入可能
    g = f ;
    // OK、ムーブ代入可能
    g = std::move(f) ;
}
~~~

ステートレスラムダではないキャプチャーをするラムダ式のクロージャーオブジェクトは今までどおりデフォルト構築可能ではないし代入可能でもない。

~~~c++
int main ()
{
    int x { } ;
    // キャプチャーするラムダ式
    auto f = [=]{ return x ; } ;
    // 違法、デフォルト構築不可
    decltype(f) g ;
    // 違法、代入不可
    g = f ;
}
~~~

この機能は次に説明する機能と合わせて使うことで真価を発揮する。