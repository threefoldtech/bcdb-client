require "./spec_helper"
require "json"
require "uuid"

describe Bcdb::Client do
   it "add acl to put & update function" do
    client = Bcdb::Client.new unixsocket: "/tmp/bcdb.sock", db: "db", namespace: "example"
    random_tag = "#{UUID.random.to_s}"
    tags = {"example" => random_tag, "tag" => "abc"}
    acl = client.acl.set("r--", [1,2])
    
    key = client.put value: "a", tags: tags, acl: acl

    res = client.get(key)
    res["tags"][":acl"].should eq acl.to_s

    new_acl = client.acl.set("rw-", [3,4])
    client.update key: key, value: "a", tags: tags, acl: new_acl
    res = client.get(key)
    res["tags"][":acl"].should eq new_acl.to_s
  end
  
  it "works" do
    client = Bcdb::Client.new unixsocket: "/tmp/bcdb.sock", db: "db", namespace: "example" 
    random_tag = "#{UUID.random.to_s}"
    tags = {"example" => random_tag, "tag2" => "v2"}
    
    key = client.put("a", tags)
    
    res = client.get(key)
    res["data"].should eq "a"
    res["tags"]["example"].should eq random_tag
    res["tags"]["tag2"].should eq "v2"

    client.update(key, "b", tags)
    
    sleep 0.001
    
    res = client.get(key)
    res["data"].should eq "b"
    res["tags"]["example"].should eq random_tag
    res["tags"]["tag2"].should eq "v2"

    res = client.fetch(key)
    res["data"].should eq "b"
    res["tags"]["example"].should eq random_tag
    res["tags"]["tag2"].should eq "v2"

    acl = client.acl.set("r--", [1,2])
    res = client.acl.get(acl)

    res["permission"].should eq "r--"
    res["users"].size.should eq 2
    res["users"].as(Array(Int32)).sort.should eq [1,2]
    
    res = client.acl.update(acl, "rwd")
    res = client.acl.get(acl)
    res["permission"].should eq "rwd"
    res["users"].size.should eq 2
    res["users"].as(Array(Int32)).sort.should eq [1,2]
   

    res = client.acl.grant(acl, [3,4])
    res = client.acl.get(acl)
    res["permission"].should eq "rwd"
    res["users"].size.should eq 4
    
    res["users"].as(Array(Int32)).sort.should eq [1,2, 3, 4]

    res = client.acl.revoke(acl, [1,4])
    res = client.acl.get(acl)
    res["permission"].should eq "rwd"
    res["users"].size.should eq 2
    
    res["users"].as(Array(Int32)).sort.should eq [2, 3]

    (0..100).each do |_|
      res = client.find({"example" => random_tag})
    end
   
    res.should eq [key]

    client.delete(key)
    begin
      res = client.get(key)
      raise "Should have raised exception"
    rescue exception
      Bcdb::NotFoundError
    end  
  end

  it "pool" do
    client = Bcdb::Client.new unixsocket: "/tmp/bcdb.sock", db: "db", namespace: "example" 
    10.times do |i|
      spawn do
        random_tag = "#{UUID.random.to_s}"
        tags = {"example" => random_tag, "tag2" => "v2"}
        begin
          client.put("a")
        rescue exception
          raise "Should not have raised exception"
        end
      end
    end
    sleep(1)

  end

  it "pool2" do
    client = Bcdb::Client.new unixsocket: "/tmp/bcdb.sock", db: "db", namespace: "example" 
    random_tag = "#{UUID.random.to_s}"
    tags = {"example" => random_tag, "tag2" => "v2"}
    key = client.put("a", tags)
    key2 = client.put("a", tags)
    key3 = client.put("a", tags)
    key4 = client.put("a", tags)
    key5 = client.put("a", tags)
    key6 = client.put("a", tags)
    key7 = client.put("a", tags)
    key8 = client.put("a", tags)
    key9 = client.put("a", tags)


    1.times do |i|
      spawn do
        res = client.find({"example" => random_tag})
        client.get(key)
        client.get(key2)
        client.get(key3)
        client.get(key4)
      end
    end

    sleep(1 )

  end


end
