# 入门

Jackson中有个ObjectMapper类很是实用，用于Java对象与JSON的互换。

## Java对象转换为JSON：


```
User user=new User(); //Java Object
ObjectMapper mapper = new ObjectMapper();
mapper.writeValueAsString(user); //返回字符串
//输出格式化后的字符串(有性能损耗)
mapper.defaultPrettyPrintingWriter().writeValueAsString(user);
mapper.writeValue(new File("c:\\user.json"), user); //指定文件写入
//设置序列化配置(全局),设置序列化时不输出空值.
sharedMapper.getSerializationConfig().setSerializationInclusion(Inclusion.NON_NULL);
```

## JSON反序列化为Java对象：


```
ObjectMapper mapper = new ObjectMapper();//解析器支持解析单引号
mapper.configure(Feature.ALLOW_SINGLE_QUOTES,true);//解析器支持解析结束符
mapper.configure(Feature.ALLOW_UNQUOTED_CONTROL_CHARS,true);
HashMap jsonMap = mapper.readValue(json,HashMap.class); //转换为HashMap对象
```

# Jackson支持3种使用方式:

## Data Binding：最方便使用.

### Full Data Binding：

```
private static final String MODEL_BINDING = "{\"name\":\"name1\",\"type\":1}";  
    public void fullDataBinding() throws Exception{  
        ObjectMapper mapper = new ObjectMapper();  
        Model user = mapper.readValue(MODEL_BINDING, Model.class);//readValue到一个实体类中.  
        System.out.println(user.getName());  
        System.out.println(user.getType());  
    }
```

### Model类：



```
private static class Model{  
        private String name;  
        private int type;  
          
        public String getName() {  
            return name;  
        }  
        public void setName(String name) {  
            this.name = name;  
        }  
        public int getType() {  
            return type;  
        }  
        public void setType(int type) {  
            this.type = type;  
        }  
    }
```

### Raw Data Binding：


```
/** 
    Concrete Java types that Jackson will use for simple data binding are: 
    JSON Type       Java Type 
    object          LinkedHashMap<String,Object> 
    array           ArrayList<Object> 
    string          String 
    number(no fraction) Integer, Long or BigInteger (smallest applicable) 
    number(fraction)    Double(configurable to use BigDecimal) 
    true|false      Boolean 
    null            null 
    */  
    public void rawDataBinding() throws Exception{  
        ObjectMapper mapper = new ObjectMapper();  
        HashMap map = mapper.readValue(MODEL_BINDING,HashMap.class);//readValue到一个原始数据类型.  
        System.out.println(map.get("name"));  
        System.out.println(map.get("type"));  
    }
```

### generic Data Binding：



```
private static final String GENERIC_BINDING = "{\"key1\":{\"name\":\"name2\",\"type\":2},\"key2\":{\"name\":\"name3\",\"type\":3}}";  
    public void genericDataBinding() throws Exception{  
        ObjectMapper mapper = new ObjectMapper();  
        HashMap<String,Model> modelMap = mapper.readValue(GENERIC_BINDING,new TypeReference<HashMap<String,Model>>(){});//readValue到一个范型数据中.  
        Model model = modelMap.get("key2");  
        System.out.println(model.getName());  
        System.out.println(model.getType());  
    }
```

## Tree Model：最灵活。



```
private static final String TREE_MODEL_BINDING = "{\"treekey1\":\"treevalue1\",\"treekey2\":\"treevalue2\",\"children\":[{\"childkey1\":\"childkey1\"}]}";  
    public void treeModelBinding() throws Exception{  
        ObjectMapper mapper = new ObjectMapper();  
        JsonNode rootNode = mapper.readTree(TREE_MODEL_BINDING);  
        //path与get作用相同,但是当找不到该节点的时候,返回missing node而不是Null.  
        String treekey2value = rootNode.path("treekey2").getTextValue();//  
        System.out.println("treekey2value:" + treekey2value);  
        JsonNode childrenNode = rootNode.path("children");  
        String childkey1Value = childrenNode.get(0).path("childkey1").getTextValue();  
        System.out.println("childkey1Value:"+childkey1Value);  
          
        //创建根节点  
        ObjectNode root = mapper.createObjectNode();  
        //创建子节点1  
        ObjectNode node1 = mapper.createObjectNode();  
        node1.put("nodekey1",1);  
        node1.put("nodekey2",2);  
        //绑定子节点1  
        root.put("child",node1);  
        //数组节点  
        ArrayNode arrayNode = mapper.createArrayNode();  
        arrayNode.add(node1);  
        arrayNode.add(1);  
        //绑定数组节点  
        root.put("arraynode", arrayNode);  
        //JSON读到树节点  
        JsonNode valueToTreeNode = mapper.valueToTree(TREE_MODEL_BINDING);  
        //绑定JSON节点  
        root.put("valuetotreenode",valueToTreeNode);  
        //JSON绑定到JSON节点对象  
        JsonNode bindJsonNode = mapper.readValue(GENERIC_BINDING, JsonNode.class);//绑定JSON到JSON节点对象.  
        //绑定JSON节点  
        root.put("bindJsonNode",bindJsonNode);  
        System.out.println(mapper.writeValueAsString(root));  
    }
```

## Streaming API：最佳性能。
参考官方文档