# This file is a part of redmine_tags
# redMine plugin, that adds tagging support.
#
# Copyright (c) 2010 Aleksey V Zapparov AKA ixti
#
# redmine_tags is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# redmine_tags is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with redmine_tags.  If not, see <http://www.gnu.org/licenses/>.

require_dependency 'query'

module RedmineTags
  module Patches
    module QueryPatch
      def self.included(base)
        base.send(:include, InstanceMethods)

        base.class_eval do
          unloadable

          alias_method :statement_original, :statement
          alias_method :statement, :statement_extended

          alias_method :available_filters_original, :available_filters
          alias_method :available_filters, :available_filters_extended

          base.add_available_column(QueryColumn.new(:tags))
        end
      end


      module InstanceMethods
        def statement_extended
          filter  = filters.delete 'tags'
          clauses = statement_original

          if filter
            filters.merge!( 'tags' => filter )

            values    = values_for('tags').clone
            if operator_for('tags').eql?('w') # [ 'is (and)', 'w' ]
              compare   = 'IN'
              issues = Issue.tagged_with(values, :match_all => true)
            elsif operator_for('tags').eql?('x') # [ 'is (or)', 'x' ]
              compare = 'IN'
              issues = Issue.tagged_with(values, :any => true)
            elsif operator_for('tags').eql?('y') # [ 'is not (and)', 'y']
              compare = 'NOT IN'
              issues = Issue.tagged_with(values, :match_all => true)
            elsif operator_for('tags').eql?('z') # ['is not (or)', 'z']
              compare = 'NOT IN'
              issues = Issue.tagged_with(values, :any => true)
            end

            ids_list  = issues.collect{ |issue| issue.id }.push(0).join(',')

            clauses << " AND ( #{Issue.table_name}.id #{compare} (#{ids_list}) ) "
          end

          clauses
        end


        def available_filters_extended
          unless @available_filters
            available_filters_original.merge!({ 'tags' => {
              :type   => :tags,
              :order  => 6,
              :values => Issue.available_tags(:project => project).collect{ |t| [t.name, t.name] }
            }})
          end
          @available_filters
        end
      end
    end
  end
end

