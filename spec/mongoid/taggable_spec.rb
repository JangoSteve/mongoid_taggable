# Copyright (c) 2010 Wilker Lúcio <wilkerlucio@gmail.com>
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

require File.join(File.dirname(__FILE__), %w[.. spec_helper])

class MyModel
  include Mongoid::Document
  include Mongoid::Taggable

  field :attr
  taggable
end

describe Mongoid::Taggable do
  context "saving tags from plain text" do
    let(:model) { MyModel.new }

    it "should set tags array from string" do
      model.tags = "some,new,tag"
      model.tags_array.should == %w[some new tag]
    end

    it "should retrieve tags string from array" do
      model.tags_array = %w[some new tags]
      model.tags.should == "some,new,tags"
    end

    it "should strip tags before put in array" do
      model.tags = "now ,  with, some spaces  , in places "
      model.tags_array.should == ["now", "with", "some spaces", "in places"]
    end
  end

  context "changing separator" do
    before :all do
      MyModel.tags_separator = ";"
    end

    after :all do
      MyModel.tags_separator = ","
    end

    let(:model) { MyModel.new }

    it "should split with custom separator" do
      model.tags = "some;other;separator"
      model.tags_array.should == %w[some other separator]
    end

    it "should join with custom separator" do
      model.tags_array = %w[some other sep]
      model.tags.should == "some;other;sep"
    end
  end

  context "tag & count aggregation" do
    it "should generate the aggregate collection name based on model" do
      MyModel.tags_aggregation_collection.should == "my_models_tags_aggregation"
    end

    it "should be disabled by default" do
      MyModel.create!(:tags => "sample,tags")
      MyModel.tags.should == []
    end

    context "when enabled" do
      before :all do
        MyModel.tag_aggregation = true
      end

      after :all do
        MyModel.tag_aggregation = false
      end

      let!(:models) do
        [
          MyModel.create!(:tags => "food,ant,bee"),
          MyModel.create!(:tags => "juice,food,bee,zip"),
          MyModel.create!(:tags => "honey,strip,food")
        ]
      end

      it "should list all saved tags distinct and ordered" do
        MyModel.tags.should == %w[ant bee food honey juice strip zip]
      end

      it "should list all tags with their weights" do
        MyModel.tags_with_weight.should == [
          ['ant', 1],
          ['bee', 2],
          ['food', 3],
          ['honey', 1],
          ['juice', 1],
          ['strip', 1],
          ['zip', 1]
        ]
      end

      it "should update when tags are edited" do
        MyModel.should_receive(:aggregate_tags!)
        models.first.update_attributes(:tags => 'changed')
      end

      it "should not update if tags are unchanged" do
        MyModel.should_not_receive(:aggregate_tags!)
        models.first.update_attributes(:attr => "changed")
      end
    end
  end

  context "#self.tagged_with" do
    let!(:models) do
      [
        MyModel.create!(:tags => "tag1,tag2,tag3"),
        MyModel.create!(:tags => "tag2"),
        MyModel.create!(:tags => "tag1", :attr => "value")
      ]
    end

    it "should return all tags with single tag input" do
      MyModel.tagged_with("tag2").sort_by{|a| a.id.to_s}.should == [models.first, models.second].sort_by{|a| a.id.to_s}
    end

    it "should return all tags with tags array input" do
      MyModel.tagged_with(%w{tag2 tag1}).should == [models.first]
    end

    it "should return all tags with tags string input" do
      MyModel.tagged_with("tag2,tag1").should == [models.first]
    end

    it "should be able to be part of methods chain" do
      MyModel.tagged_with("tag1").where(:attr => "value").should == [models.last]
    end
  end
end
