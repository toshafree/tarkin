require 'rails_helper'

PASSWORD = 'the password'
NEW_PASSWORD = 'the new password'

RSpec.describe Item, type: :model do
  before do
    @user = User.create(name: 'name', email: 'email@email.com', password: 'password')
    @group = @user.add Group.new(name: 'group')
    @item = @group.add Item.new(password: PASSWORD), authorization_user: @user
  end
  it "should have the crypted password" do
    expect(@item.password_crypted).to_not be_nil
  end
  it "should return the password in context of the user" do
    expect(@item.password(authorization_user: @user)).to eq PASSWORD
  end
  describe "even when reloaded from DB" do
    before do
      @loaded_user = User.find(@user.id)
      @loaded_user.password = 'password'
      @loaded_item = Item.find(@item.id)
    end
    it ", the password should be readable" do
      #expect(@loaded_user.item_password(@loaded_item)).to eq PASSWORD
      expect(@loaded_item.password(authorization_user: @user)).to eq PASSWORD
    end
    describe "should be able to change the value of password" do
      before do 
        @loaded_item.authorize @user
        @loaded_item.password = NEW_PASSWORD
        @loaded_item.save!
        @loaded_item = Item.find(@item.id) # reload
      end
      it { expect(@loaded_item.password(authorization_user: @user)).to eq NEW_PASSWORD }
    end
  end
end

RSpec.describe Item, type: :model do
  before do 
    @users = 3.times.map{|i| User.create(name: "name#{i}", email: "email#{i}@example.com", password: "password#{i}")}
    @groups = @users.map{|user| user << Group.new(name: "group #{user.name}")}
    @groups.each_with_index {|group, i| group.authorize(@users[i])}
    @items = @groups.map {|group| group << Item.new(password: "password for #{group.name}")}
  end
  3.times.each do |i|
    it { expect(@users[i].items.count).to eq 1 }
    it { expect(@users[i].items.first.password(authorization_user: @users[i])).to eq "password for group #{@users[i].name}" }
  end
  describe "add item[1] to group[0], authorized by user[1]" do
    before do
      @groups[0].add @items[1], authorization_user: @users[1]
    end
    it { expect(@users[0].items.count).to eq 2 }
    it { expect(@users[0].items.last).to eq @items[1] }
    it "user[0] should be now able to read item[1] password" do
      expect(@items[1].password(authorization_user: @users[0])).to eq "password for group name1"
    end
    it "but not item[2] password" do
      expect{@items[2].password(authorization_user: @users[0])}.to raise_error Tarkin::ItemNotAccessibleException
    end
  end
end