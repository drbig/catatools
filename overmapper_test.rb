#!/usr/bin/env ruby
# coding: utf-8
#
# See LICENSE.txt for licensing information.

require 'minitest/autorun'
require_relative 'overmapper.rb'

class TestOvermapper < Minitest::Test
  def setup
    # default config
    @conf = {
      mapx: 180, mapy: 180, level: 10, scale: 2, verbose: false,
      grid: true, origin: true
    }
  end

  def test_parse_seen_data
    [
      ['1 10', [[0, 0, 9, 0]]],
      ['0 10 1 5', [[10, 0, 14, 0]]],
      ['1 200', [[0, 0, 179, 0], [0, 1, 19, 1]]],
    ].each do |(input, output)|
      assert_equal output, parse_seen_data(input)
    end
  end

  def test_parse_note
    [
      ['<:W;AUTO: goes up', Note.new('AUTO: goes up', :w, '<')],
      ['>:W;AUTO: goes down', Note.new('AUTO: goes down', :w, '>')],
      ['GOOD STUFF HERE!', Note.new('GOOD STUFF HERE!')],
      ['R;!:TANK DRONE', Note.new('TANK DRONE', :r, '!')],
      ['C;H:Base 1', Note.new('Base 1', :c, 'H')],
    ].each do |(input, output)|
      assert_equal output, parse_note(input)
    end
  end
end
