Jackson是一个简单基于Java应用库，**Jackson可以轻松的将Java对象转换成json对象和xml文档，同样也可以将json、xml转换成Java对象**。
```
graph LR
Java对象-->json或xml
json或xml-->Java对象
```

Jackson所依赖的jar包较少，**简单易用并且性能也要相对高些**，并且Jackson社区相对比较活跃，更新速度也比较快。

# 特点
- 容易使用：jackson API提供了一个高层次外观，以简化常用的用例。


- 无需创建映射：API提供了默认的映射大部分对象序列化。

- 性能高：快速，低内存占用，适合大型对象图表或系统。

- 干净的JSON：jackson创建一个干净和紧凑的JSON结果，这是让人很容易阅读。

- 不依赖：库不需要任何其他的库，除了JDK。

- 开源代码：jackson是开源的，可以免费使用。

# 三种方式处理JSON
提供了三种不同的方法来处理JSON

## 流式API 
- 读取并将JSON内容写入作为离散事件。 JsonParser读取数据，而JsonGenerator写入数据。它是三者中最有效的方法，是最低的开销和最快的读/写操作。它类似于Stax解析器XML。

## 树模型 
- 准备JSON文件在内存里以树形式表示。 ObjectMapper构建JsonNode节点树。这是最灵活的方法。它类似于XML的DOM解析器。

## 数据绑定 
- 转换JSON并从POJO（普通Java对象）使用属性访问或使用注释。

它有两个类型:

#### 简单的数据绑定 
- 转换JSON和Java Maps, Lists, Strings, Numbers, Booleans 和null 对象。

#### 全部数据绑定 
- 转换JSON为任意JAVA类型。

ObjectMapper读/写JSON两种类型的数据绑定。数据绑定是最方便的方式是类似XML的JAXB解析器。

# 操作步骤
- 第1步：创建ObjectMapper对象。
创建ObjectMapper对象。它是一个可重复使用的对象。


```
ObjectMapper mapper = new ObjectMapper();
```

- 第2步：反序列化JSON到对象。
从JSON对象使用readValue()方法来获取。通过JSON字符串和对象类型作为参数JSON字符串/来源。


```
//Object to JSON Conversion
Student student = mapper.readValue(jsonString, Student.class);
```

- 第3步：序列化对象到JSON。
使用writeValueAsString()方法来获取对象的JSON字符串表示。


```
//Object to JSON Conversion		
jsonString = mapper.writeValueAsString(student);
```


#  ObjectMapper类
ObjectMapper类是Jackson库的主要类。它提供一些功能将转换成Java对象匹配JSON结构，反之亦然。它使用JsonParser和JsonGenerator的实例实现JSON实际的读/写。

# Jackson对象序列化
将Java对象序列化到一个JSON文件，然后再读取JSON文件获取转换为对象。

在这个例子中，创建了Student类。创建将有学生对象以JSON表示在一个student.json文件。


```
import java.io.File;
import java.io.IOException;

import org.codehaus.jackson.JsonGenerationException;
import org.codehaus.jackson.JsonParseException;
import org.codehaus.jackson.map.JsonMappingException;
import org.codehaus.jackson.map.ObjectMapper;

public class JacksonTester {
   public static void main(String args[]){
      JacksonTester tester = new JacksonTester();
      try {
         Student student = new Student();
         student.setAge(10);
         student.setName("Mahesh");
         tester.writeJSON(student);

         Student student1 = tester.readJSON();
         System.out.println(student1);

      } catch (JsonParseException e) {
         e.printStackTrace();
      } catch (JsonMappingException e) {
         e.printStackTrace();
      } catch (IOException e) {
         e.printStackTrace();
      }
   }

   private void writeJSON(Student student) throws JsonGenerationException, JsonMappingException, IOException{
      ObjectMapper mapper = new ObjectMapper();	
      mapper.writeValue(new File("student.json"), student);
   }

   private Student readJSON() throws JsonParseException, JsonMappingException, IOException{
      ObjectMapper mapper = new ObjectMapper();
      Student student = mapper.readValue(new File("student.json"), Student.class);
      return student;
   }
}

class Student {
   private String name;
   private int age;
   public Student(){}
   public String getName() {
      return name;
   }
   public void setName(String name) {
      this.name = name;
   }
   public int getAge() {
      return age;
   }
   public void setAge(int age) {
      this.age = age;
   }
   public String toString(){
      return "Student [ name: "+name+", age: "+ age+ " ]";
   }	
}
```

# Jackson数据绑定
数据绑定API用于JSON转换和使用属性访问或使用注解POJO(普通Java对象)。以下是它的两个类型。

- 简单数据绑定：转换JSON，从Java Maps, Lists, Strings, Numbers, Booleans 和 null 对象。


- 完整数据绑定：转换JSON到任何JAVA类型。我们将在下一章分别绑定。

ObjectMapper读/写JSON两种类型的数据绑定。数据绑定是最方便的方式是类似XML的JAXB解析器。

## 简单的数据绑定
简单的数据绑定是指JSON映射到Java核心数据类型。下表列出了JSON类型和Java类型之间的关系。


Sr. No.|	JSON 类型|	Java 类型
---|---|---| 
1|	object|	LinkedHashMap<String,Object>
2	|array|	ArrayList<Object>
3|	string|	String
4|	complete number	|Integer, Long or BigInteger
5|	fractional number|	Double / BigDecimal
6|	true | false|	Boolean
7|	null|	null

让我们来看看简单的数据操作绑定。在这里将映射JAVA基本类型直接JSON，反之亦然。

```
import java.io.File;
import java.io.IOException;
import java.util.HashMap;
import java.util.Map;

import org.codehaus.jackson.JsonGenerationException;
import org.codehaus.jackson.JsonParseException;
import org.codehaus.jackson.map.JsonMappingException;
import org.codehaus.jackson.map.ObjectMapper;

public class JacksonTester {
   public static void main(String args[]){
      JacksonTester tester = new JacksonTester();
         try {
            ObjectMapper mapper = new ObjectMapper();

            Map<String,Object> studentDataMap = new HashMap<String,Object>(); 
            int[] marks = {1,2,3};

            Student student = new Student();
            student.setAge(10);
            student.setName("Mahesh");
            // JAVA Object
            studentDataMap.put("student", student);
            // JAVA String
            studentDataMap.put("name", "Mahesh Kumar");   		
            // JAVA Boolean
            studentDataMap.put("verified", Boolean.FALSE);
            // Array
            studentDataMap.put("marks", marks);

            mapper.writeValue(new File("student.json"), studentDataMap);
            //result student.json
			//{ 
            //   "student":{"name":"Mahesh","age":10},
            //   "marks":[1,2,3],
            //   "verified":false,
            //   "name":"Mahesh Kumar"
            //}
            studentDataMap = mapper.readValue(new File("student.json"), Map.class);

            System.out.println(studentDataMap.get("student"));
            System.out.println(studentDataMap.get("name"));
            System.out.println(studentDataMap.get("verified"));
            System.out.println(studentDataMap.get("marks"));
      } catch (JsonParseException e) {
         e.printStackTrace();
      } catch (JsonMappingException e) {
         e.printStackTrace();
      } catch (IOException e) {
            e.printStackTrace();
      }
   }
}

class Student {
   private String name;
   private int age;
   public Student(){}
   public String getName() {
      return name;
   }
   public void setName(String name) {
      this.name = name;
   }
   public int getAge() {
      return age;
   }
   public void setAge(int age) {
      this.age = age;
   }
   public String toString(){
      return "Student [ name: "+name+", age: "+ age+ " ]";
   }	
}
```

## 全数据绑定
完全数据绑定是指JSON映射到任何Java对象。

```
//Create an ObjectMapper instance
ObjectMapper mapper = new ObjectMapper();	
//map JSON content to Student object
Student student = mapper.readValue(new File("student.json"), Student.class);
//map Student object to JSON content
mapper.writeValue(new File("student.json"), student);
```

