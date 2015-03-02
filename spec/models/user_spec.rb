# == Schema Information
#
# Table name: users
#
#  id                      :integer          not null, primary key
#  name                    :string(256)      not null
#  email                   :string(256)      not null
#  public_key_pem          :string(4096)     not null
#  private_key_pem_crypted :binary           not null
#  created_at              :datetime         not null
#  updated_at              :datetime         not null
#

require 'rails_helper'

RSpec.describe User, type: :model do
  it { should respond_to :name }
  it { should respond_to :email }
  it { should respond_to :private_key }
  it { should respond_to :public_key }
  it { should respond_to :password }
  describe "with no password given" do
    before do
      @user = User.new(name: 'name', email: 'email@email.com')
    end
    it { expect(@user).not_to be_valid }
  end
  describe "with given password" do
    before do
      @user = User.new(name: 'name', email: 'email@email.com', password: 'password')
      @user2 = User.new(name: 'name2', email: 'email@EMAIL.com', password: 'password2')
    end
    it "should be valid, but not authenticated yet" do
      expect(@user).to be_valid 
      expect(@user.password).to eq "*" * 8
      expect(@user.public_key.class).to eq OpenSSL::PKey::RSA
      expect(@user.private_key.class).to eq OpenSSL::PKey::RSA
      expect(@user.authenticated?).to eq false
    end
    describe "when loading from the database" do
      before do
        @user.save!
        @loaded_user = User.find(@user.id)
      end
      it "the new user with the same email should not be valid" do
        expect(@user2).not_to be_valid 
      end
      it "saved user should be authenticated" do 
        expect(@user.authenticated?).to eq true 
      end
      it "without password" do
        expect(@loaded_user.password).to be_nil
        expect(@loaded_user.public_key.class).to eq OpenSSL::PKey::RSA
        expect{@loaded_user.private_key}.to raise_error(Tarkin::WrongPasswordException)
        expect(@loaded_user.authenticated?).to eq false
      end
      describe "with wrong password" do
        before do
          @loaded_user.password = "wrong"
        end
        it "should not be authenticated and not have valid private_key" do
          expect(@loaded_user.password).not_to be_nil
          expect(@loaded_user.public_key.class).to eq OpenSSL::PKey::RSA
          expect{@loaded_user.private_key}.to raise_error(Tarkin::WrongPasswordException)
          expect(@loaded_user.authenticated?).to eq false
        end
        it "should be able to change the password" do
          expect{@loaded_user.change_password "new password"}.to raise_error(Tarkin::WrongPasswordException)
        end
      end
      describe "with good password" do
        before do
          @loaded_user.password = "password"
        end
        it "should be authenticated and have valid private key" do
          expect(@loaded_user.password).not_to be_nil
          expect(@loaded_user.private_key.class).to eq OpenSSL::PKey::RSA
          expect(@loaded_user.authenticated?).to eq true
        end
        describe "should be able to change the password" do
          before do
            @loaded_user.change_password "new password"
            @loaded_user.save
          end
          it "and have new password after it" do
            expect(@loaded_user.password.length).to eq "new password".length
            expect(@loaded_user.private_key.class).to eq OpenSSL::PKey::RSA
            expect(@loaded_user.authenticated?).to eq true
          end
          describe "and to load it with a new password" do
            before do
              @new_password_user = User.find(@loaded_user.id)
              @new_password_user.password = "new password"
            end
            it "should be valid" do
              expect(@new_password_user.private_key.class).to eq OpenSSL::PKey::RSA
              expect(@new_password_user.authenticated?).to eq true
            end
          end
        end
      end
    end
  end
  describe "with group" do
    before do 
      @user = User.create(name: 'name', email: 'email@email.com', password: 'password')
    end
    describe "should be able to add a new group without authentication" do
      before do
        @group = Group.new(name: 'group')
        @user.add @group
      end
      it { expect(@user.groups.first).to eq @group }
      it { expect(@group.new_record?).to eq false }
      describe "and add the other user" do
        before do
          @other_user = User.create(name: 'name2', email: 'email2@email.com', password: 'password2')
        end
        describe "authorization" do 
          before do 
            @other_user.add @group, authorization_user: @user
          end
          it { expect(@group.users.count).to eq 2}
        end
        describe "without authorization" do 
          it { expect{@user.add @group, authorization_user: @other_user}.to raise_error Tarkin::GroupNotAccessibleException }
        end
      end
      describe "with item" do
        before do 
          @group.authorize @user
          @group2 = @user << Group.new(name: 'group2')
          @group2.authorize @user
          @items = [@group << Item.create(password:'item1'), @group2 << Item.new(password:'item2')]
        end
        it { expect(@user.items.count).to eq 2 }
        it { expect(@user.items).to eq @items }
        describe "should have the item" do
          before do
            #@user.add @items[0] 
          end
        end
      end

    end
  end
end
