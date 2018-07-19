defmodule CryptoTest do
  use ExUnit.Case
  alias BlockchainNode.Crypto

  test "it symmetrically encrypts and decrypts an input" do
    password = "password!"
    data = "some random string of data"
    {iv, tag, encrypted_data} = Crypto.encrypt(password, data)
    decrypted_data = Crypto.decrypt(password, iv, tag, encrypted_data)
    assert decrypted_data == data
  end

  test "it returns an error if the provided password is incorrect" do
    password = "password!"
    data = "some random string of data"
    {iv, tag, encrypted_data} = Crypto.encrypt(password, data)
    res = Crypto.decrypt("notthepassword", iv, tag, encrypted_data)
    assert res == :error
  end
end
