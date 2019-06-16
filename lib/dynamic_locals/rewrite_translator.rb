module DynamicLocals
  module RewriteTranslator
    extend self

    def translate(original_src, locals_hash: :locals)
      line_offsets = [0]
      idx = 0
      while idx = original_src.index("\n", idx)
        idx += 1
        line_offsets << idx
      end

      root = RubyVM::AbstractSyntaxTree.parse(original_src)
      rewrites = find_rewrites(root)
      rewrites =
        rewrites.sort_by do |node, replacement|
          range_from(line_offsets, node).end
        end.reverse

      src = original_src.dup
      rewrites.each do |node, rewrite|
        range = range_from(line_offsets, node)
        src[range] = rewrite
      end

      src
    end

    private

    def position_from(line_offsets, line, column)
      line_offsets[line-1] + column
    end

    def range_from(line_offsets, node)
      first = position_from(line_offsets, node.first_lineno, node.first_column)
      last  = position_from(line_offsets, node.last_lineno, node.last_column)
      first...last
    end

    def find_rewrites(node)
      return [] unless RubyVM::AbstractSyntaxTree::Node === node
      return [] if node.type == :DEFINED
      rewrites = node.children.flat_map { |child| find_rewrites(child)  }
      if node.type == :VCALL
        name = node.children[0]
        replacement = "locals.fetch(#{name.inspect}){ #{name}() }"
        rewrites << [node, replacement]
      end
      rewrites
    end
  end
end
