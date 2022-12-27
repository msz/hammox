defmodule Hammox.TypeMatchErrorTest do
  use ExUnit.Case, async: true

  alias Hammox.TypeMatchError

  describe "standard error" do
    test "reason" do
      error = TypeMatchError.exception({:error, reason()})

      assert error.message ==
               """

               Returned value {:ok, %{__struct__: Post, body: "post body", post_body: "nil"}} does not match type {:ok, Post.t()} | {:error, any()}.

                 Value {:ok, %{__struct__: Post, body: "post body", post_body: "nil"}} does not match type {:ok, Post.t()} | {:error, any()}.

                   1st tuple element :ok does not match 1st element type :error.

                     Value :ok does not match type :error.
               """
               |> String.replace_trailing("\n", "")
    end
  end

  describe "pretty error" do
    setup do
      Application.put_env(:hammox, :pretty, true)

      on_exit(fn ->
        Application.delete_env(:hammox, :pretty)
      end)
    end

    test "reason" do
      error = TypeMatchError.exception({:error, reason()})

      assert error.message ==
               """

               Returned value {:ok, %{__struct__: Post, body: \"post body\", post_body: \"nil\"}} does not match type 
               {:ok, Post.t()}
                | {:error, any()}.

                 Value {:ok, %{__struct__: Post, body: \"post body\", post_body: \"nil\"}} does not match type 
                 {:ok, Post.t()}
                  | {:error, any()}.

                   1st tuple element :ok does not match 1st element type 
                   :error.

                     Value :ok does not match type 
                     :error.
               """
               |> String.replace_trailing("\n", "")
    end
  end

  defp reason do
    [
      {:return_type_mismatch,
       {:ok,
        %{
          __struct__: Post,
          body: "post body",
          post_body: "nil"
        }},
       {:type, 49, :union,
        [
          {:type, 0, :tuple,
           [
             {:atom, 0, :ok},
             {:remote_type, 49, [{:atom, 0, Post}, {:atom, 0, :t}, []]}
           ]},
          {:type, 0, :tuple, [{:atom, 0, :error}, {:type, 49, :any, []}]}
        ]}},
      {:type_mismatch,
       {:ok,
        %{
          __struct__: Post,
          body: "post body",
          post_body: "nil"
        }},
       {:type, 49, :union,
        [
          {:type, 0, :tuple,
           [
             {:atom, 0, :ok},
             {:remote_type, 49, [{:atom, 0, Post}, {:atom, 0, :t}, []]}
           ]},
          {:type, 0, :tuple, [{:atom, 0, :error}, {:type, 49, :any, []}]}
        ]}},
      {:tuple_elem_type_mismatch, 0, :ok, {:atom, 0, :error}},
      {:type_mismatch, :ok, {:atom, 0, :error}}
    ]
  end
end
